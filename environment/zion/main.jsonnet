local cloudConfig = import './cloudConfig.jsonnet';
local loadBalancerConfig = import './loadBalancerConfig.jsonnet';
local composition = import '../../modules/composition.jsonnet';

composition {items: std.flattenArrays([
  loadBalancerConfig.items,
  cloudConfig.items,
])}
