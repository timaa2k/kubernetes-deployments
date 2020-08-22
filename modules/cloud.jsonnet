local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';
local filestash = import './filestash.jsonnet';
local minio = import './minio.jsonnet';

{
  namespace:: kube.Namespace('default'),
  persistentVolumeData:: error 'persistentVolumeData must be provided',

} + composition {items: std.flattenArrays([

  minio {
    namespace: $.namespace,
    persistentVolume: $.persistentVolumeData,
    encryptedConfig: std.parseJson(importstr './sealed-minio-config.json'),
  }.items,

  filestash {
    namespace: $.namespace,
    encryptedConfig: std.parseJson(importstr './sealed-filestash-config.json'),
  }.items,

])}
