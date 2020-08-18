local composition = import '../../modules/composition.jsonnet';
local kube = import '../../lib/kube.libsonnet';
local metallb = import '../../modules/metallb.jsonnet';

{
  namespace:: kube.Namespace('metallb'),

} + composition {items: std.flattenArrays([

  [ $.namespace ],

  metallb { namespace: $.namespace }.items,

])}
