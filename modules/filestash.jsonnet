local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'filestash';

{
  namespace:: kube.Namespace('default'),
  persistentVolume:: error 'persistentVolume must be provided',
  serveUrl:: error 'items must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  persistentVolumeClaim:: kube.PersistentVolumeClaim(name) + $.namespaceRef {
    storageClass: $.persistentVolume.spec.storageClassName,
    storage: $.persistentVolume.spec.capacity.storage,
    spec+: { volumeName: $.persistentVolume.metadata.name },
  },

  deployment:: kube.Deployment(name) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          volumes_+: {
            config: kube.PersistentVolumeClaimVolume($.persistentVolumeClaim),
          },
          containers_+: {
            'default': kube.Container(name) {
              image: 'docker.io/machines/filestash:fe802d8',
              volumeMounts_+: {
                config: {
                  mountPath: '/app/data/state/config/',
                  subPath: 'config',
                },
              },
              ports_+: { http: { containerPort: 8334 } },
              env_+: {
                APPLICATION_URL: $.serveUrl,
                ONLYOFFICE_URL: 'http://onlyoffice',
              },
            },
            'onlyoffice': kube.Container('onlyoffice') {
              image: 'docker.io/onlyoffice/documentserver:5.6.0.17',
              ports_+: { http: { containerPort: 80 } },
  }}}}}},

  service:: kube.Service(name) + $.namespaceRef {
    target_pod: $.deployment.spec.template,
    spec+: {
      type: 'LoadBalancer'
  }},

} + composition {items: [
  $.persistentVolumeClaim,
  $.deployment,
  $.service,
]}
