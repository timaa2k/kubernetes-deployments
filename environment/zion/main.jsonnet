local kube = import '../../lib/kube.libsonnet';
local cloud = import '../../modules/cloud.jsonnet';
local composition = import '../../modules/composition.jsonnet';

{
  namespace:: kube.Namespace('cloud'),

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
    $.namespace,
    $.storageClass,
    $.persistentVolume,
  ],

  cloud {
    namespace: $.namespace,
    persistentVolume: $.persistentVolume,
    serveUrl: 'zion:30001',
    filestashNodePort: 30001,
    minioNodePort: 30000,
  }.items,

])}
