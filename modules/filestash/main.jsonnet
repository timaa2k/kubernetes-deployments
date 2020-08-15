local kube = import "../lib/kube.libsonnet";
local list = import "../utils/kube.libsonnet";

local name = 'filestash';

{
  serveUrl:: error "items must be provided",
  nodePort:: 30000,

  namespace:: {metadata+: {namespace: name}},

  deployment:: kube.Deployment(name) + $.namespace {
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
    $.deployment,
    $.service,
  ],
}
