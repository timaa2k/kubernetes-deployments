local kube = import '../lib/kube.libsonnet';
local composition = import './composition.jsonnet';

local name = 'elasticsearch-master';

{
  namespace:: kube.Namespace('default'),
  persistentVolume:: error 'persistentVolume must be provided',

  namespaceRef:: {metadata+: {namespace: $.namespace.metadata.name}},

  statefulSet:: kube.StatefulSet(name) + $.namespaceRef {
    local data = name + '-data',
    metadata+: { annotations+: { esMajorVersion: 8 } },
    spec+: {
      serviceName: $.serviceHeadless.metadata.name,
      volumeClaimTemplates_+: {
        [data]: {
          storageClass: $.persistentVolume.spec.storageClassName,
          storage: $.persistentVolume.spec.capacity.storage,
          spec+: { volumeName: $.persistentVolume.metadata.name },
      }},
      podManagementPolicy: 'Parallel',
      template+: {
        spec+: {
          securityContext: { runAsUser: 1000, fsGroup: 100 },
          enableServiceLinks: true,
          /* initContainers: [{ */
          /*     name: 'configure-sysctl', */
          /*     image: 'docker.elastic.co/elasticsearch/elasticsearch:8.0.0-SNAPSHOT', */
          /*     command: ['sysctl', '-w', 'vm.max_map_count=262144'], */
          /*     securityContext: { privileged: true, runAsUser: 0 }, */
          /* }], */
          containers_+: {
            default: kube.Container(name) {
              image: 'docker.elastic.co/elasticsearch/elasticsearch:8.0.0-SNAPSHOT',
              volumeMounts_+: {
                [data]: { mountPath: '/usr/share/elasticsearch/data' },
              },
              ports_+: {
                http: { containerPort: 9200 },
                transport: { containerPort: 9300 },
              },
              env_+: {
                'cluster.name': 'elasticsearch',
                'cluster.initial_master_nodes': 'elasticsearch-master-0',
                'discovery.seed_hosts': 'elasticsearch-master-headless',
                'network.host': '0.0.0.0',
                'node.name': kube.FieldRef('metadata.name'),
                'node.data': true,
                'node.ingest': true,
                'node.master': true,
                ES_JAVA_OPTS: '-Xmx1g -Xms1g',
              },
              resources: {
                limits: { cpu: 1, memory: '2Gi' },
                requests: { cpu: 1, memory: '2Gi' },
              },
              securityContext: {
                capabilities: { drop: ['ALL'] },
                runAsUser: 1000,
                runAsNonRoot: true,
              },
              readinessProbe: {
                exec: {
                  command: [
                    'sh',
                    '-c',
                    "#!/usr/bin/env bash -e\n# If the node is starting up wait for the cluster to be ready (request params: \"wait_for_status=green\u0026timeout=1s\" )\n# Once it has started only check that the node itself is responding\nSTART_FILE=/tmp/.es_start_file\n\nhttp () {\n  local path=\"${1}\"\n  local args=\"${2}\"\n  set -- -XGET -s\n\n  if [ \"$args\" != \"\" ]; then\n    set -- \"$@\" $args\n  fi\n\n  if [ -n \"${ELASTIC_USERNAME}\" ] \u0026\u0026 [ -n \"${ELASTIC_PASSWORD}\" ]; then\n    set -- \"$@\" -u \"${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}\"\n  fi\n\n  curl --output /dev/null -k \"$@\" \"http://127.0.0.1:9200${path}\"\n}\n\nif [ -f \"${START_FILE}\" ]; then\n  echo 'Elasticsearch is already running, lets check the node is healthy'\n  HTTP_CODE=$(http \"/\" \"-w %{http_code}\")\n  RC=$?\n  if [[ ${RC} -ne 0 ]]; then\n    echo \"curl --output /dev/null -k -XGET -s -w '%{http_code}' \\${BASIC_AUTH} http://127.0.0.1:9200/ failed with RC ${RC}\"\n    exit ${RC}\n  fi\n  # ready if HTTP code 200, 503 is tolerable if ES version is 6.x\n  if [[ ${HTTP_CODE} == \"200\" ]]; then\n    exit 0\n  elif [[ ${HTTP_CODE} == \"503\" \u0026\u0026 \"8\" == \"6\" ]]; then\n    exit 0\n  else\n    echo \"curl --output /dev/null -k -XGET -s -w '%{http_code}' \\${BASIC_AUTH} http://127.0.0.1:9200/ failed with HTTP code ${HTTP_CODE}\"\n    exit 1\n  fi\n\nelse\n  echo 'Waiting for elasticsearch cluster to become ready (request params: \"wait_for_status=green\u0026timeout=1s\" )'\n  if http \"/_cluster/health?wait_for_status=green\u0026timeout=1s\" \"--fail\" ; then\n    touch ${START_FILE}\n    exit 0\n  else\n    echo 'Cluster is not yet ready (request params: \"wait_for_status=green\u0026timeout=1s\" )'\n    exit 1\n  fi\nfi\n"
                  ],
                },
                initialDelaySeconds: 10,
                timeoutSeconds: 5,
                periodSeconds: 10,
                successThreshold: 3,
                failureThreshold: 3
  }}}}}}},

  service:: kube.Service(name) + $.namespaceRef {
    target_pod: $.statefulSet.spec.template,
    spec+: {
      ports: [
        { port: 9200, targetPort: 9200, name: 'http' },
        { port: 9300, targetPort: 9300, name: 'transport' },
      ],
      type: 'LoadBalancer',
  }},

  serviceHeadless:: kube.Service(name + '-headless') + $.namespaceRef {
    target_pod: $.statefulSet.spec.template,
    metadata+: {
      annotations+: {
        'service.alpha.kubernetes.io/tolerate-unready-endpoints': true,
    }},
    spec+: {
      ports: [
        { port: 9200, targetPort: 9200, name: 'http' },
        { port: 9300, targetPort: 9300, name: 'transport' },
      ],
      publishNotReadyAddresses: true,
      type: 'LoadBalancer',
  }},

  podDisruptionBudget:: kube.PodDisruptionBudget(name) + $.namespaceRef {
    target_pod:: $.statefulSet.spec.template,
    spec+: {
      maxUnavailable: 1
  }},

} + composition {items: [
  $.service,
  $.serviceHeadless,
  $.podDisruptionBudget,
  $.statefulSet,
]}
