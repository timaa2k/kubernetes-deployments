local kube = import "../lib/kube.libsonnet";
local kutils = import "../utils/kube.libsonnet";

local minio(namespace, accessKey, secretKey, nodePort) = kutils.List({

  namespace:: {metadata+: {namespace: namespace}},

  persistent_volume: kube.PersistentVolume('minio') {
    spec+: {
      capacity: { storage: '931Gi' },
      hostPath: { path: '/mnt/hdd/cloud-data' },
      accessModes: [ 'ReadWriteOnce' ],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'local-backup-hdd',
  }},

  persistent_volume_claim: kube.PersistentVolumeClaim('minio') + $.namespace {
    storageClass: 'local-backup-hdd',
    storage: '931G',
    spec+: { volumeName: 'minio' },
  },

  secret: kube.Secret('minio') + $.namespace {
    data_+:{
      accesskey: accessKey,
      secretkey: secretKey,
  }},

  service_account: kube.ServiceAccount('minio') + $.namespace {},

  deployment: kube.Deployment('minio') + $.namespace {
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: $.service_account.metadata.name,
          securityContext: { runAsUser: 1000, runAsGroup: 1000, fsGroup: 1000 },
          volumes_+: {
            export: kube.PersistentVolumeClaimVolume($.persistent_volume_claim),
          },
          containers_+: {
            'default': kube.Container('minio') {
              image: 'minio/minio:RELEASE.2020-06-14T18-32-17Z',
              volumeMounts_+: { export: { mountPath: '/export' } },
              ports_+: { http: { containerPort: 9000 } },
              env_+: {
                MINIO_ACCESS_KEY: kube.SecretKeyRef($.secret, 'accesskey'),
                MINIO_SECRET_KEY: kube.SecretKeyRef($.secret, 'secretkey'),
                MINIO_API_READY_DEADLINE: '5s',
              },
              command: [
                '/bin/sh', '-ce',
                '/usr/bin/docker-entrypoint.sh minio -S /etc/minio/certs/ server /export',
              ],
              resources: { requests: { memory: '2Gi' } },
              livenessProbe: {
                httpGet: {
                  path: '/minio/health/live',
                  port: 'http',
                  scheme: 'HTTP',
                },
                initialDelaySeconds: 5,
                timeoutSeconds: 1,
                periodSeconds: 5,
                successThreshold: 1,
                failureThreshold: 1,
              },
              readinessProbe: {
                httpGet: {
                  path: '/minio/health/ready', port: 'http', scheme: 'HTTP',
                },
                initialDelaySeconds: 30,
                timeoutSeconds: 6,
                periodSeconds: 5,
                successThreshold: 1,
                failureThreshold: 3,
              },
  }}}}}},

  service: kube.Service('minio') + $.namespace {
    local service = self,
    target_pod: $.deployment.spec.template,
    spec+: {
      type: 'NodePort',
      ports: [
        {
          port: service.port,
          name: service.target_pod.spec.containers[0].ports[0].name,
          targetPort: service.target_pod.spec.containers[0].ports[0].containerPort,
          'nodePort': nodePort,
        },
      ],
  }},

});

{
  Deployment:: minio,
}
