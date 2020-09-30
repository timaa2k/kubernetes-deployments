local kube = (import '../lib/kube.libsonnet');
local composition = import './composition.jsonnet';

local name = 'influxdb';

{
  namespace:: kube.Namespace('default'),
  persistentVolume:: error 'persistentVolume must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  configMap:: kube.ConfigMap(name) + $.namespaceRef {
    data: {
      'influxdb.conf': 'reporting-disabled = false\nbind-address = \":8088\"\n\n[meta]\n  dir = \"/var/lib/influxdb/meta\"\n\n[data]\n  dir = \"/var/lib/influxdb/data\"\n  wal-dir = \"/var/lib/influxdb/wal\"\n\n[coordinator]\n\n[retention]\n\n[shard-precreation]\n\n[monitor]\n\n[subscriber]\n\n[http]\n\n# TODO: allow multiple graphite listeners\n\n[[graphite]]\n\n# TODO: allow multiple collectd listeners with templates\n\n[[collectd]]\n\n# TODO: allow multiple opentsdb listeners with templates\n\n[[opentsdb]]\n\n# TODO: allow multiple udp listeners with templates\n\n[[udp]]\n\n[continuous_queries]\n\n[logging]\n',
  }},

  serviceAccount:: kube.ServiceAccount(name) + $.namespaceRef {},

  statefulSet:: kube.StatefulSet(name) + $.namespaceRef {
    local data = name + '-data',
    local config = 'config',
    spec+: {
      serviceName: $.service.metadata.name,
      volumeClaimTemplates_+: {
        [data]: {
          storageClass: $.persistentVolume.spec.storageClassName,
          storage: $.persistentVolume.spec.capacity.storage,
          spec+: { volumeName: $.persistentVolume.metadata.name },
      }},
      template+: {
        spec+: {
          serviceAccountName: $.serviceAccount.metadata.name,
          volumes_+: {
            [config]: kube.ConfigMapVolume($.configMap),
          },
          containers_+: {
            default: kube.Container(name) {
              image: 'influxdb:1.8.0-alpine',
              volumeMounts_+: {
                [data]: { mountPath: '/var/lib/influxdb' },
                [config]: { mountPath: '/etc/influxdb' },
              },
              ports_+: {
                api: { containerPort: 8086 },
                rpc: { containerPort: 8088 },
              },
              livenessProbe: {
                httpGet: {
                  path: '/ping', port: 'api', scheme: 'HTTP',
                },
                initialDelaySeconds: 30,
                timeoutSeconds: 5,
                periodSeconds: 10,
                successThreshold: 1,
                failureThreshold: 3
              },
              readinessProbe: {
                httpGet: {
                  path: '/ping', port: 'api', scheme: 'HTTP',
                },
                initialDelaySeconds: 5,
                timeoutSeconds: 1,
                periodSeconds: 10,
                successThreshold: 1,
                failureThreshold: 3
              },
  }}}}}},

  service:: kube.Service(name) + $.namespaceRef {
    target_pod: $.statefulSet.spec.template,
    spec+: {
      ports: [
        {
          name: 'api',
          protocol: 'TCP',
          port: 8086,
          targetPort: 'api',
        },
        {
          name: 'rpc',
          protocol: 'TCP',
          port: 8088,
          targetPort: 'rpc',
        },
      ],
      type: 'LoadBalancer',
  }},

} + composition {items: [
  $.configMap,
  $.serviceAccount,
  $.statefulSet,
  $.service,
]}
