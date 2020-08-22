local kube = import '../../lib/kube.libsonnet';
local cloud = import '../../modules/cloud.jsonnet';
local composition = import '../../modules/composition.jsonnet';
local metallb = import '../../modules/metallb.jsonnet';
local sealedSecrets = import '../../modules/sealed-secrets.jsonnet';
local traefik = import '../../modules/traefik.jsonnet';

{
  namespaces:: {
    kubeSystem: kube.Namespace('kube-system'),
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
    $.namespaces.kubeSystem,
    $.namespaces.metallb,
    $.namespaces.traefik,
    $.namespaces.cloud,
    $.storageClass,
    $.persistentVolumeTraefik,
    $.persistentVolumeMinio,
  ],

  sealedSecrets {
    namespace: $.namespaces.kubeSystem,
  }.items,

  metallb {
    namespace: $.namespaces.metallb,
  }.items,

  traefik {
    namespace: $.namespaces.traefik,
    persistentVolume: $.persistentVolumeTraefik,
  }.items,

  cloud {
    namespace: $.namespaces.cloud,
    persistentVolumeData: $.persistentVolumeMinio,
  }.items,

])}
