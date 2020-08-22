local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'filestash';

{
  namespace:: kube.Namespace('default'),
  encryptedConfig:: error 'encryptedConfig must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  secret:: kube.SealedSecret(name) + $.namespaceRef {
    spec+: {
      encryptedData: {
        'config.json': $.encryptedConfig['config.json'],
  }}},

  deployment:: kube.Deployment(name) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          volumes_+: {
            config: {secret: {secretName: $.secret.metadata.name} },
          },
          containers_+: {
            'default': kube.Container(name) {
              image: 'docker.io/machines/filestash:fe802d8',
              volumeMounts_+: {
                config: {
                  mountPath: '/app/data/state/config/',
                  readOnly: true,
                },
              },
              ports_+: { http: { containerPort: 8334 } },
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
  $.secret,
  $.deployment,
  $.service,
]}
