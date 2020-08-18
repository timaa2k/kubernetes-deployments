local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'metallb';
local controller = name + '-controller';
local speaker = name + '-speaker';
local configWatcher = name + '-config-watcher';

{
  namespace:: kube.Namespace('default'),

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  clusterRoleController:: kube.ClusterRole(controller) + $.namespaceRef {
    rules: [{
      apiGroups: [''], resources: ['services'],
      verbs: ['get', 'list', 'watch', 'update'],
    },{
      apiGroups: [''], resources: ['services/status'],
      verbs: ['update'],
    },{
      apiGroups: [''], resources: ['events'],
      verbs: ['create', 'patch'],
    }],
  },

  serviceAccountController:: kube.ServiceAccount(controller) + $.namespaceRef,

  clusterRolesBindingController:: kube.ClusterRoleBinding(controller) + $.namespaceRef {
    subjects_: [ $.serviceAccountController ],
    roleRef_: $.clusterRoleController,
  },

  deploymentController:: kube.Deployment(controller) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: $.serviceAccountController.metadata.name,
          securityContext: { runAsUser: 65534, runAsNonRoot: true },
          containers_+: {
            'default': kube.Container(controller) {
              image: 'metallb/controller:v0.8.1',
              ports_+: { monitoring: { containerPort: 7472 } },
              args: [ '--port=7472', '--config=metallb-config' ],
              securityContext: {
                capabilities: { drop: ['all'] },
                readOnlyRootFilesystem: true,
                allowPrivilegeEscalation: false,
  }}}}}}},

  podSecurityPolicySpeaker:: {
    kind: 'PodSecurityPolicy',
    apiVersion: 'policy/v1beta1',
    metadata: {
      name: speaker,
      labels: { name: speaker },
    },
    spec: {
      privileged: true,
      allowedCapabilities: ['NET_ADMIN', 'NET_RAW', 'SYS_ADMIN'],
      volumes: ['*'],
      hostNetwork: true,
      hostPorts: [{ min: 7472, max: 7472 }],
      seLinux: { rule: 'RunAsAny' },
      runAsUser: { rule: 'RunAsAny' },
      supplementalGroups: { rule: 'RunAsAny' },
      fsGroup: { rule: 'RunAsAny' },
      allowPrivilegeEscalation: false,
    }
  } + $.namespaceRef,

  clusterRoleSpeaker:: kube.ClusterRole(speaker) + $.namespaceRef {
    rules: [{
      apiGroups: [''], resources: ['services', 'endpoints', 'nodes'],
      verbs: ['get', 'list', 'watch'],
    },{
      apiGroups: [''], 'resources': ['events'],
      verbs: ['create', 'patch'],
    },{
      verbs: ['use'],
      apiGroups: ['extensions'], resources: ['podsecuritypolicies'],
      resourceNames: ['metallb-speaker'],
    }],
  },

  serviceAccountSpeaker:: kube.ServiceAccount(speaker) + $.namespaceRef,

  clusterRolesBindingSpeaker:: kube.ClusterRoleBinding(speaker) + $.namespaceRef {
    subjects_: [ $.serviceAccountSpeaker ],
    roleRef_: $.clusterRoleSpeaker,
  },

  daemonSetSpeaker:: kube.DaemonSet(speaker) + $.namespaceRef {
    spec+: {
      template+: {
        spec+: {
          tolerations: [{
            key: 'node-role.kubernetes.io/master',
            effect: 'NoSchedule',
          }],
          serviceAccountName: $.serviceAccountSpeaker.metadata.name,
          hostNetwork: true,
          containers_+: {
            'default': kube.Container(speaker) {
              image: 'metallb/speaker:v0.8.1',
              ports_+: { monitoring: { hostPort: 7472, containerPort: 7472 } },
              args: ['--port=7472', '--config=metallb-config'],
              env_+: {
                METALLB_NODE_NAME: kube.FieldRef('spec.nodeName'),
                METALLB_HOST: kube.FieldRef('status.hostIP'),
              },
              securityContext: {
                capabilities: {
                  drop: ['ALL'], add: ['NET_ADMIN','NET_RAW','SYS_ADMIN'],
                },
                readOnlyRootFilesystem: true,
                allowPrivilegeEscalation: false,
  }}}}}}},

  roleConfigWatcher:: kube.Role(configWatcher) + $.namespaceRef {
    rules: [{
      verbs: ['get', 'list', 'watch'],
      apiGroups: [''],
      resources: ['configmaps'],
    }],
  },

  roleBindingConfigWatcher:: kube.RoleBinding(configWatcher) + $.namespaceRef {
    subjects_: [ $.serviceAccountController, $.serviceAccountSpeaker ],
    roleRef_: $.roleConfigWatcher,
  },

  configMap:: kube.ConfigMap('metallb-config') + $.namespaceRef {
    data: {
      config: "address-pools:\n- name: default\n  protocol: layer2\n  addresses:\n  - 192.168.178.128-192.168.178.254\n",
  }},

} + composition {items: [
  $.clusterRoleController,
  $.serviceAccountController,
  $.clusterRolesBindingController,
  $.deploymentController,
  $.podSecurityPolicySpeaker,
  $.clusterRoleSpeaker,
  $.serviceAccountSpeaker,
  $.clusterRolesBindingSpeaker,
  $.daemonSetSpeaker,
  $.roleConfigWatcher,
  $.roleBindingConfigWatcher,
  $.configMap,
]}
