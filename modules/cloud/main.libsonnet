local filestash = import '../filestash/main.libsonnet';
local minio = import '../minio/main.libsonnet';

local deployment(
  namespace,
  serveUrl,
  accessKey,
  secretKey,
  nodePort,
) = {
  apiVersion: 'v1',
  kind: 'List',
  items: std.flattenArrays([
    [
      {
        apiVersion: 'storage.k8s.io/v1',
        kind: 'StorageClass',
        metadata: {
          name: 'local-backup-hdd',
        },
        provisioner: 'kubernetes.io/no-provisioner',
        volumeBindingMode: 'WaitForFirstConsumer',
      },
      {
        apiVersion: 'v1',
        kind: 'Namespace',
        metadata: {
          name: namespace,
          labels: {
            name: namespace,
          },
        },
      },
    ],
    minio.Deployment(
      namespace=namespace,
      accessKey=accessKey,
      secretKey=secretKey,
    ).items,
    filestash.Deployment(
      namespace=namespace,
      serveUrl=serveUrl,
      nodePort=nodePort,
    ).items,
  ]),
};

{
  Deployment:: deployment,
}
