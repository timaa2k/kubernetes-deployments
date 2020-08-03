local cloud = import '../../modules/cloud/main.libsonnet';

function(
  minioAccessKey='AKIAIOSFODNN7EXAMPLE',
  minioSecretKey='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
) {
  apiVersion: 'v1',
  kind: 'List',
  items: std.flattenArrays([
    cloud.Deployment(
      namespace='cloud',
      serveUrl='zion:30001',
      filestashNodePort=30001,
      accessKey=minioAccessKey,
      secretKey=minioSecretKey,
      minioNodePort=30000,
    ).items,
  ]),
}
