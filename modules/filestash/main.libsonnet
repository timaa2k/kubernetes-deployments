local name = 'filestash';

local deployment(namespace, serveUrl, nodePort) = {
  apiVersion: 'v1',
  kind: 'List',
  items: [
    {
      kind: 'Deployment',
      apiVersion: 'apps/v1',
      metadata: {
        name: 'filestash',
        namespace: namespace,
        labels: {
          app: name,
        },
      },
      spec: {
        replicas: 1,
        selector: {
          matchLabels: {
            app: name,
          },
        },
        template: {
          metadata: {
            labels: {
              app: name,
            },
          },
          spec: {
            containers: [
              {
                name: name,
                image: 'docker.io/machines/filestash:fe802d8',
                ports: [
                  {
                    containerPort: 8334,
                    protocol: 'TCP',
                  },
                ],
                env: [
                  {
                    name: 'APPLICATION_URL',
                    value: serveUrl,
                  },
                  {
                    name: 'ONLYOFFICE_URL',
                    value: 'http://onlyoffice',
                  },
                ],
                imagePullPolicy: 'IfNotPresent',
              },
              {
                name: 'onlyoffice',
                image: 'docker.io/onlyoffice/documentserver:5.6.0.17',
                ports: [
                  {
                    containerPort: 80,
                    protocol: 'TCP',
                  },
                ],
                imagePullPolicy: 'IfNotPresent',
              },
            ],
            restartPolicy: 'Always',
          },
        },
        strategy: {
          type: 'RollingUpdate',
          rollingUpdate: {
            maxUnavailable: '25%',
            maxSurge: '25%',
          },
        },
      },
    },
    {
      kind: 'Service',
      apiVersion: 'v1',
      metadata: {
        name: name,
        namespace: namespace,
      },
      spec: {
        ports: [
          {
            name: 'http',
            protocol: 'TCP',
            port: 8334,
            targetPort: 8334,
            nodePort: nodePort,
          },
        ],
        selector: {
          app: name,
        },
        type: 'NodePort',
        externalTrafficPolicy: 'Cluster',
      },
    },
  ],
};

{
  Deployment:: deployment,
}
