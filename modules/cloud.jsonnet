local kube = import '../lib/kube.libsonnet';
local list = import './list.jsonnet';
local filestash = import './filestash.jsonnet';
local minio = import './minio.jsonnet';

local name = 'cloud';

{
  serveUrl:: error 'serveUrl must be provided',
  filestashNodePort:: error 'filestashNodePort must be provided',
  minioNodePort:: error 'minioNodePort must be provided',
  namespace:: {metadata+: {namespace: name}},

} + list {items: std.flattenArrays([
  [
    kube.StorageClass('local-backup-hdd') {
      provisioner: 'kubernetes.io/no-provisioner',
    } + { volumeBindingMode: 'WaitForFirstConsumer' },
    kube.Namespace($.namespace.metadata.namespace),
  ],

  minio {
    nodePort: $.minioNodePort,
    namespace: $.namespace,
  }.items,

  filestash {
    serveUrl: $.serveUrl,
    nodePort: $.filestashNodePort,
    namespace: $.namespace,
  }.items,
])}
