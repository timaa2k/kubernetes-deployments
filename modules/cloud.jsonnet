local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';
local filestash = import './filestash.jsonnet';
local minio = import './minio.jsonnet';

{
  namespace:: kube.Namespace('default'),
  persistentVolume:: error 'persistentVolume must be provided',
  serveUrl:: error 'serveUrl must be provided',

} + composition {items: std.flattenArrays([

  minio {
    persistentVolume: $.persistentVolume,
    namespace: $.namespace,
  }.items,

  filestash {
    serveUrl: $.serveUrl,
    namespace: $.namespace,
  }.items,

])}
