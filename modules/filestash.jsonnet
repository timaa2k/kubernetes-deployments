local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'filestash';

{
  namespace:: kube.Namespace('default'),
  serveUrl:: error 'items must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  deployment:: kube.Deployment(name) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            'default': kube.Container(name) {
              image: 'docker.io/machines/filestash:fe802d8',
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
  $.deployment,
  $.service,
]}
