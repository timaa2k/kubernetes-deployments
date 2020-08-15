local list = import '../../modules/utils/kube.libsonnet';

local cloud = import '../../modules/cloud/main.jsonnet';

list {
  items: cloud {
    serveUrl: 'zion:30001',
    filestashNodePort: 30001,
    minioNodePort: 30000,
  }.items,
}
