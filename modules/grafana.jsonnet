local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'grafana';

{
  namespace:: kube.Namespace('default'),

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  podSecurityPolicy:: {
    kind: 'PodSecurityPolicy',
    apiVersion: 'policy/v1beta1',
    metadata: {
      name: name,
      labels: { name: name },
    },
    spec: {
      requiredDropCapabilities: [
        'FOWNER',
        'FSETID',
        'KILL',
        'SETGID',
        'SETUID',
        'SETPCAP',
        'NET_BIND_SERVICE',
        'NET_RAW',
        'SYS_CHROOT',
        'MKNOD',
        'AUDIT_WRITE',
        'SETFCAP',
      ],
      volumes: [
        'configMap',
        'emptyDir',
        'projected',
        'secret',
        'downwardAPI',
        'persistentVolumeClaim',
      ],
      seLinux: { rule: 'RunAsAny' },
      runAsUser: { rule: 'RunAsAny' },
      supplementalGroups: { rule: 'RunAsAny' },
      fsGroup: { rule: 'RunAsAny' },
      allowPrivilegeEscalation: false,
    }
  } + $.namespaceRef,

  serviceAccount:: kube.ServiceAccount(name) + $.namespaceRef,

  clusterRole:: kube.ClusterRole(name) {
    rules: [],
  },

  clusterRoleBinding:: kube.ClusterRoleBinding(name) {
    subjects_: [ $.serviceAccount ],
    roleRef_: $.clusterRole,
  },

  role:: kube.Role(name) + $.namespaceRef {
    rules: [{
      verbs: ['use'],
      apiGroups: ['extensions'],
      resources: ['podsecuritypolicies'],
      resourceNames: ['grafana'],
    }],
  },

  roleBinding:: kube.RoleBinding(name) + $.namespaceRef {
    subjects_: [ $.serviceAccount ],
    roleRef_: $.role,
  },

  configMap:: kube.ConfigMap(name) + $.namespaceRef {
    data+: {
      'grafana.ini': std.manifestIni(
        {
          sections: {
            analytics: {
              check_for_updates: 'false',
            },
            grafana_net: {
              url: '"https://grafana.net"',
            },
            log: {
              mode: 'console',
            },
            paths: {
              data: '"/var/lib/grafana/data"',
              logs: '"/var/log/grafana"',
              plugins: '"/var/lib/grafana/plugins"',
              provisioning: '"/etc/grafana/provisioning"',
            },
            users: {
              default_theme: 'light',
            },
            auth: {
              disable_login_form: 'true',
            },
            'auth.basic': {
              enabled: 'false',
            },
            'auth.anonymous': {
              enabled: 'true',
              org_role: 'Admin',
            },
          },
        }
      ),
      'datasources.yaml': std.manifestYamlDoc(
        {
          apiVersion: 1,
          datasources: [
            {
              name: 'InfluxDB_v1',
              type: 'influxdb',
              access: 'proxy',
              database: 'NOAA_water_database',
              user: '',
              password: '',
              url: 'http://influxdb.influx:8086',
              jsonData: {
                httpMode: 'GET',
              },
            },
          ],
        },
      ),
  }},

  secret:: kube.Secret(name) + $.namespaceRef {
    data_+: {
      'admin-user': 'admin',
      'admin-password': 'admin',
      'ldap-toml': '',
  }},

  deployment:: kube.Deployment(name) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: $.serviceAccount.metadata.name,
          securityContext: { runAsUser: 472, runAsGroup: 472, fsGroup: 472 },
          volumes_+: {
            config: kube.ConfigMapVolume($.configMap),
            datasources: kube.ConfigMapVolume($.configMap),
            storage: kube.EmptyDirVolume(),
          },
          containers_+: {
            'default': kube.Container(name) {
              image: 'grafana/grafana:7.2.0',
              volumeMounts_+: {
                config: {
                  mountPath: '/etc/grafana/grafana.ini',
                  subPath: 'grafana.ini',
                },
                datasources: {
                  mountPath: '/etc/grafana/provisioning/datasources/datasources.yaml',
                  subPath: 'datasources.yaml',
                },
                storage: { mountPath: '/var/lib/grafana' },
              },
              ports_+: {
                grafana: { containerPort: 3000 },
              },
              env_+: {
                GF_SECURITY_ADMIN_USER: kube.SecretKeyRef($.secret, 'admin-user'),
                GF_SECURITY_ADMIN_PASSWORD: kube.SecretKeyRef($.secret, 'admin-password'),
              },
              livenessProbe: {
                httpGet: { path: '/api/health', port: 3000 },
                initialDelaySeconds: 60,
                timeoutSeconds: 30,
                failureThreshold: 10,
              },
              readinessProbe: {
                httpGet: { path: '/api/health', port: 3000 },
  }}}}}}},

  service:: kube.Service(name) + $.namespaceRef {
    target_pod: $.deployment.spec.template,
    port: 80,
    spec+: {
      type: 'LoadBalancer',
  }},

} + composition {items: [
  $.podSecurityPolicy,
  $.serviceAccount,
  $.clusterRole,
  $.clusterRoleBinding,
  $.role,
  $.roleBinding,
  $.configMap,
  $.secret,
  $.deployment,
  $.service,
]}
