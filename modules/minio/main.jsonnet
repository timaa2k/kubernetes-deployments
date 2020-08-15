local kube = import "../lib/kube.libsonnet";
local list = import "../utils/kube.libsonnet";

local name = 'minio';

{
  accessKey:: 'AKIAIOSFODNN7EXAMPLE',
  secretKey:: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  nodePort:: error "nodePort must be provided",

  namespace:: {metadata+: {namespace: name}},

  persistentVolume:: kube.PersistentVolume(name) {
    spec+: {
      capacity: { storage: '931Gi' },
      hostPath: { path: '/mnt/hdd/cloud-data' },
      accessModes: [ 'ReadWriteOnce' ],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'local-backup-hdd',
  }},

  persistentVolumeClaim:: kube.PersistentVolumeClaim(name) + $.namespace {
    storageClass: 'local-backup-hdd',
    storage: '931G',
    spec+: { volumeName: name },
  },

  secret:: kube.Secret(name) + $.namespace {
    data_+:{
      accesskey: $.accessKey,
      secretkey: $.secretKey,
  }},

  serviceAccount:: kube.ServiceAccount(name) + $.namespace {},

  deployment:: kube.Deployment(name) + $.namespace {
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: $.serviceAccount.metadata.name,
          securityContext: { runAsUser: 1000, runAsGroup: 1000, fsGroup: 1000 },
          volumes_+: {
            export: kube.PersistentVolumeClaimVolume($.persistentVolumeClaim),
          },
          containers_+: {
            'default': kube.Container(name) {
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

  service:: kube.Service(name) + $.namespace {
    local service = self,
    target_pod: $.deployment.spec.template,
    spec+: {
      type: 'NodePort',
      ports: [
        {
          port: service.port,
          name: service.target_pod.spec.containers[0].ports[0].name,
          targetPort: service.target_pod.spec.containers[0].ports[0].containerPort,
          'nodePort': $.nodePort,
        },
      ],
  }},

} + list {
  items: [
    $.persistentVolume,
    $.persistentVolumeClaim,
    $.secret,
    $.serviceAccount,
    $.deployment,
    $.service,
  ],
}
