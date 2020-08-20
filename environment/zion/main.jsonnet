local kube = import '../../lib/kube.libsonnet';
local cloud = import '../../modules/cloud.jsonnet';
local composition = import '../../modules/composition.jsonnet';
local metallb = import '../../modules/metallb.jsonnet';
local traefik = import '../../modules/traefik.jsonnet';

{
  namespaces:: {
    metallb: kube.Namespace('metallb'),
    traefik: kube.Namespace('traefik'),
    cloud: kube.Namespace('cloud'),
  },

  storageClass:: kube.StorageClass('local-backup-hdd') {
    provisioner: 'kubernetes.io/no-provisioner',
  } + { volumeBindingMode: 'WaitForFirstConsumer' },

  persistentVolumeTraefik: kube.PersistentVolume('traefik') {
    spec+: {
      capacity: { storage: '128Mi' },
      hostPath: { path: '/mnt/hdd/config-data/traefik' },
      accessModes: [ 'ReadWriteOnce' ],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: $.storageClass.metadata.name,
  }},

  persistentVolumeFilestash: kube.PersistentVolume('filestash') {
    spec+: {
      capacity: { storage: '128Mi' },
      hostPath: { path: '/mnt/hdd/config-data/filestash' },
      accessModes: [ 'ReadWriteOnce' ],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: $.storageClass.metadata.name,
  }},

  persistentVolumeMinio:: kube.PersistentVolume('minio') {
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
    $.namespaces.traefik,
    $.namespaces.cloud,
    $.storageClass,
    $.persistentVolumeTraefik,
    $.persistentVolumeFilestash,
    $.persistentVolumeMinio,
  ],

  metallb {
    namespace: $.namespaces.metallb,
  }.items,

  traefik {
    namespace: $.namespaces.traefik,
    persistentVolume: $.persistentVolumeTraefik,
  }.items,

  cloud {
    namespace: $.namespaces.cloud,
    persistentVolumeConfig: $.persistentVolumeFilestash,
    persistentVolumeData: $.persistentVolumeMinio,
    serveUrl: '192.168.178.128:8334',
  }.items,

])}
