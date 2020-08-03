local filestash = import '../filestash/main.libsonnet';
local minio = import '../minio/main.libsonnet';

local deployment(
  namespace,
  serveUrl,
  filestashNodePort,
  accessKey,
  secretKey,
  minioNodePort,
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
      nodePort=minioNodePort,
    ).items,
    filestash.Deployment(
      namespace=namespace,
      serveUrl=serveUrl,
      nodePort=filestashNodePort,
    ).items,
  ]),
};

{
  Deployment:: deployment,
}
