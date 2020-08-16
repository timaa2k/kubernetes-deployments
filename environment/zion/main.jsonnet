local cloud = import '../../modules/cloud.jsonnet';

cloud {
  serveUrl: 'zion:30001',
  filestashNodePort: 30001,
  minioNodePort: 30000,
}
