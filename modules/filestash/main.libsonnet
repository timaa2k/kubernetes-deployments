local kube = import "../lib/kube.libsonnet";
local kutils = import "../utils/kube.libsonnet";

local filestash(namespace, serveUrl, nodePort) = kutils.List({

  deployment: kube.Deployment('filestash') {
    local resource = self,
    metadata+: { 'namespace': namespace },
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            'default': kube.Container('filestash') {
              image: 'docker.io/machines/filestash:fe802d8',
              ports_+: { http: { containerPort: 8334 } },
              env_+: {
                APPLICATION_URL: serveUrl,
                ONLYOFFICE_URL: 'http://onlyoffice',
              },
            },
            'onlyoffice': kube.Container('onlyoffice') {
              image: 'docker.io/onlyoffice/documentserver:5.6.0.17',
              ports_+: { http: { containerPort: 80 } },
  }}}}}},

  service: kube.Service('filestash') {
    local service = self,
    metadata+: { 'namespace': namespace, },
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
  Deployment:: filestash,
}
