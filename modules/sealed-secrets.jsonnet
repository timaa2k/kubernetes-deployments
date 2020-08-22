local kube = import '../lib/kube.libsonnet';
local controller = import '../sealed-secrets/controller.jsonnet';
local composition = import './composition.jsonnet';

{
  namespace:: kube.Namespace('default'),

  namespaceRef:: { metadata+: { namespace: $.namespace.metadata.name } },

  sealedSecrets:: controller {
    namespace:: $.namespaceRef,
    controllerImage:: 'quay.io/bitnami/sealed-secrets-controller:v0.12.5',
    imagePullPolicy:: 'IfNotPresent',
  },

} + composition {
  items: [$.sealedSecrets[o] for o in std.objectFields($.sealedSecrets)],
}
