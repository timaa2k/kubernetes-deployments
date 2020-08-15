local cloud = import '../../modules/cloud/main.libsonnet';
local list = import '../../modules/utils/kube.libsonnet';

list {
  items: cloud {
    serveUrl: 'zion:30001',
    filestashNodePort: 30001,
    minioNodePort: 30000,
  }.items,
}
