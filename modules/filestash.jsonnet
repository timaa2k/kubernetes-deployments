local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'filestash';

{
  namespace:: kube.Namespace('default'),
  serveUrl:: error 'items must be provided',
  nodePort:: error 'nodePort must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  deployment:: kube.Deployment(name) + $.namespaceRef {
    local resource = self,
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
  $.deployment,
  $.service,
]}