local kube = (import '../lib/kube.libsonnet') { _assert:: false };
local composition = import './composition.jsonnet';

local name = 'minio';

{
  namespace:: kube.Namespace('default'),
  encryptedConfig:: error 'encryptedConfig must be provided',
  persistentVolume:: error 'persistentVolume must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  persistentVolumeClaim:: kube.PersistentVolumeClaim(name) + $.namespaceRef {
    storageClass: $.persistentVolume.spec.storageClassName,
    storage: $.persistentVolume.spec.capacity.storage,
    spec+: { volumeName: $.persistentVolume.metadata.name },
  },

  secret:: kube.SealedSecret(name) + $.namespaceRef {
    spec+: {
    encryptedData: {
      accesskey: $.encryptedConfig['accesskey'],
      secretkey: $.encryptedConfig['secretkey'],
  }}},

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
    target_pod: $.deployment.spec.template,
    spec+: {
      type: 'LoadBalancer',
  }},

} + composition {items: [
  $.persistentVolume,
  $.persistentVolumeClaim,
  $.secret,
  $.serviceAccount,
  $.deployment,
  $.service,
]}
