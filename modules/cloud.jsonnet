local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';
local filestash = import './filestash.jsonnet';
local minio = import './minio.jsonnet';

{
  namespace:: kube.Namespace('default'),
  persistentVolumeConfig:: error 'persistentVolumeConfig must be provided',
  persistentVolumeData:: error 'persistentVolumeData must be provided',
  serveUrl:: error 'serveUrl must be provided',

} + composition {items: std.flattenArrays([

  minio {
    persistentVolume: $.persistentVolumeData,
    namespace: $.namespace,
  }.items,

  filestash {
    persistentVolume: $.persistentVolumeConfig,
    serveUrl: $.serveUrl,
    namespace: $.namespace,
  }.items,

])}
