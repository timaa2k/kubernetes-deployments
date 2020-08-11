local kube = import "../lib/kube.libsonnet";
local kutils = import "../utils/kube.libsonnet";
local filestash = import '../filestash/main.libsonnet';
local minio = import '../minio/main.libsonnet';

local cloud(
  namespace,
  serveUrl,
  filestashNodePort,
  accessKey,
  secretKey,
  minioNodePort,
) = kutils.List(
  std.flattenArrays([
    [
      kube.StorageClass('local-backup-hdd') {
        provisioner: 'kubernetes.io/no-provisioner',
      } + { volumeBindingMode: 'WaitForFirstConsumer' },
      kube.Namespace(namespace) {},
    ],
    minio.Deployment(
      namespace=namespace,
      accessKey=accessKey,
      secretKey=secretKey,
      nodePort=minioNodePort,
    ).items,
    filestash.Deployment(
      namespace=namespace,
      serveUrl=serveUrl,
      nodePort=filestashNodePort,
    ).items,
  ]),
);

{
  Deployment:: cloud,
}
