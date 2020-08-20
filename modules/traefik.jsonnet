local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'traefik';

{
  namespace:: kube.Namespace('default'),
  persistentVolume:: error 'persistentVolume must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  persistentVolumeClaim:: kube.PersistentVolumeClaim(name) + $.namespaceRef {
    storageClass: $.persistentVolume.spec.storageClassName,
    storage: $.persistentVolume.spec.capacity.storage,
    spec+: { volumeName: $.persistentVolume.metadata.name },
  },

  clusterRole:: kube.ClusterRole(name) {
    rules: [{
      apiGroups: [''], resources: ['services', 'endpoints', 'secrets'],
      verbs: ['get', 'list', 'watch'],
    },{
      apiGroups: ['extensions'], resources: ['ingresses'],
      verbs: ['get', 'list', 'watch'],
    },{
      apiGroups: ['traefik.containo.us'], resources: [
        'ingressroutes',
        'ingressroutetcps',
        'ingressrouteudps',
        'middlewares',
        'tlsoptions',
        'tlsstores',
        'traefikservices',
      ],
      verbs: ['get', 'list', 'watch'],
    }],
  },

  serviceAccount:: kube.ServiceAccount(name) + $.namespaceRef,

  clusterRoleBinding:: kube.ClusterRoleBinding(name) {
    subjects_: [ $.serviceAccount ],
    roleRef_: $.clusterRole,
  },

  deployment:: kube.Deployment(name) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: $.serviceAccount.metadata.name,
          securityContext: { fsGroup: 1000 },
          volumes_+: {
            data: kube.PersistentVolumeClaimVolume($.persistentVolumeClaim),
            tmp: {emptyDir: {} },
          },
          containers_+: {
            'default': kube.Container(name) {
              image: 'traefik:2.2.8',
              securityContext: {
                capabilities: { drop: ['ALL'] },
                runAsUser: 1000,
                runAsGroup: 1000,
                runAsNonRoot: true,
                readOnlyRootFilesystem: true,
              },
              volumeMounts_+: {
                data: { mountPath: '/data'},
                tmp:  { mountPath: '/tmp' },
              },
              ports_+: {
                traefik:   { containerPort: 9000 },
                web:       { containerPort: 8000 },
                websecure: { containerPort: 8443 },
              },
              args: [
                '--entryPoints.traefik.address=:9000/tcp',
                '--entryPoints.web.address=:8000/tcp',
                '--entryPoints.websecure.address=:8443/tcp',
                '--api.dashboard=true',
                '--ping=true',
                '--providers.kubernetescrd',
                '--providers.kubernetesingress'
              ],
              livenessProbe: {
                httpGet: {
                  path: '/ping', port: 9000, scheme: 'HTTP',
                },
                initialDelaySeconds: 10,
                timeoutSeconds: 2,
                periodSeconds: 10,
                successThreshold: 1,
                failureThreshold: 3
              },
              readinessProbe: {
                httpGet: {
                  path: '/ping', port: 9000, scheme: 'HTTP',
                },
                initialDelaySeconds: 10,
                timeoutSeconds: 2,
                periodSeconds: 10,
                successThreshold: 1,
                failureThreshold: 1,
  }}}}}}},

  service:: kube.Service(name) + $.namespaceRef {
    target_pod: $.deployment.spec.template,
    spec+: {
      type: 'LoadBalancer',
  }},

} + composition {items: [
  $.persistentVolumeClaim,
  $.clusterRole,
  $.serviceAccount,
  $.clusterRoleBinding,
  $.deployment,
  $.service,
]}
