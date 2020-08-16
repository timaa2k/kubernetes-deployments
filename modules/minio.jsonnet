local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'minio';

{
  namespace:: kube.Namespace('default'),
  persistentVolume:: error 'persistentVolume must be provided',
  accessKey:: 'AKIAIOSFODNN7EXAMPLE',
  secretKey:: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  nodePort:: error 'nodePort must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  persistentVolumeClaim:: kube.PersistentVolumeClaim(name) + $.namespaceRef {
    storageClass: $.persistentVolume.spec.storageClassName,
    storage: $.persistentVolume.spec.capacity.storage,
    spec+: { volumeName: name },
  },

  secret:: kube.Secret(name) + $.namespaceRef {
    data_+:{
      accesskey: $.accessKey,
      secretkey: $.secretKey,
  }},

  serviceAccount:: kube.ServiceAccount(name) + $.namespaceRef {},

  deployment:: kube.Deployment(name) + $.namespaceRef {
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

  service:: kube.Service(name) + $.namespaceRef {
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

} + composition {items: [
  $.persistentVolume,
  $.persistentVolumeClaim,
  $.secret,
  $.serviceAccount,
  $.deployment,
  $.service,
]}
