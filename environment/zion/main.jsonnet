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

  persistentVolumeConfig:: kube.PersistentVolume('config') {
    spec+: {
      capacity: { storage: '256Mi' },
      hostPath: { path: '/mnt/hdd/config-data' },
      accessModes: [ 'ReadWriteMany' ],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: $.storageClass.metadata.name,
  }},

  persistentVolumeData:: kube.PersistentVolume('minio') {
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
    $.persistentVolumeConfig,
    $.persistentVolumeData,
  ],

  metallb {
    namespace: $.namespaces.metallb
  }.items,

  cloud {
    namespace: $.namespaces.cloud,
    persistentVolumeConfig: $.persistentVolumeConfig,
    persistentVolumeData: $.persistentVolumeData,
    serveUrl: '192.168.178.128:8334',
  }.items,

])}
