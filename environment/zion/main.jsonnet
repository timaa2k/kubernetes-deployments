local cloud = import '../../modules/cloud.jsonnet';
local composition = import '../../modules/composition.jsonnet';
local metallb = import '../../modules/metallb.jsonnet';
local kube = import '../../lib/kube.libsonnet';

{
  namespaces:: {
    metallb: kube.Namespace('metallb'),
    cloud: kube.Namespace('cloud'),
  },

  storageClass:: kube.StorageClass('local-backup-hdd') {
    provisioner: 'kubernetes.io/no-provisioner',
  } + { volumeBindingMode: 'WaitForFirstConsumer' },

  persistentVolume:: kube.PersistentVolume('minio') {
    spec+: {
      capacity: { storage: '931Gi' },
      hostPath: { path: '/mnt/hdd/cloud-data' },
      accessModes: [ 'ReadWriteOnce' ],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: $.storageClass.metadata.name,
  }},

} + composition {items: std.flattenArrays([

  [
    $.namespaces.metallb,
    $.namespaces.cloud,
    $.storageClass,
    $.persistentVolume,
  ],

  metallb {
    namespace: $.namespaces.metallb
  }.items,

  cloud {
    namespace: $.namespaces.cloud,
    persistentVolume: $.persistentVolume,
    serveUrl: '192.168.178.128:8334',
  }.items,

])}
