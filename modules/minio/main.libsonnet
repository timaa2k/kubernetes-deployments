local name = 'minio';

local deployment(namespace, accessKey, secretKey) = {
  apiVersion: 'v1',
  kind: 'List',
  items: [
    {
      kind: 'PersistentVolume',
      apiVersion: 'v1',
      metadata: {
        name: name,
        labels: {
          type: 'local',
        },
      },
      spec: {
        capacity: {
          storage: '931Gi',
        },
        hostPath: {
          path: '/mnt/hdd/minio',
          type: '',
        },
        accessModes: [
          'ReadWriteOnce',
        ],
        persistentVolumeReclaimPolicy: 'Retain',
        storageClassName: 'local-backup-hdd',
        volumeMode: 'Filesystem',
      },
    },
    {
      kind: 'PersistentVolumeClaim',
      apiVersion: 'v1',
      metadata: {
        name: name,
        namespace: namespace,
        labels: {
          app: 'minio',
        },
      },
      spec: {
        accessModes: [
          'ReadWriteOnce',
        ],
        resources: {
          requests: {
            storage: '931Gi',
          },
        },
        volumeName: 'minio',
        storageClassName: 'local-backup-hdd',
        volumeMode: 'Filesystem',
      },
    },
    {
      kind: 'Secret',
      apiVersion: 'v1',
      metadata: {
        name: name,
        namespace: namespace,
        labels: {
          app: name,
        },
      },
      data: {
        accesskey: std.base64(accessKey),
        secretkey: std.base64(secretKey),
      },
      type: 'Opaque',
    },
    {
      kind: 'ServiceAccount',
      apiVersion: 'v1',
      metadata: {
        name: name,
        namespace: namespace,
      },
    },
    {
      kind: 'Deployment',
      apiVersion: 'apps/v1',
      metadata: {
        name: name,
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
            name: 'minio',
            labels: {
              app: name,
            },
          },
          spec: {
            volumes: [
              {
                name: 'export',
                persistentVolumeClaim: {
                  claimName: 'minio',
                },
              },
            ],
            containers: [
              {
                name: 'minio',
                image: 'minio/minio:RELEASE.2020-06-14T18-32-17Z',
                command: [
                  '/bin/sh',
                  '-ce',
                  '/usr/bin/docker-entrypoint.sh minio -S /etc/minio/certs/ server /export',
                ],
                ports: [
                  {
                    name: 'http',
                    containerPort: 9000,
                    protocol: 'TCP',
                  },
                ],
                env: [
                  {
                    name: 'MINIO_ACCESS_KEY',
                    valueFrom: {
                      secretKeyRef: {
                        name: 'minio',
                        key: 'accesskey',
                      },
                    },
                  },
                  {
                    name: 'MINIO_SECRET_KEY',
                    valueFrom: {
                      secretKeyRef: {
                        name: 'minio',
                        key: 'secretkey',
                      },
                    },
                  },
                  {
                    name: 'MINIO_API_READY_DEADLINE',
                    value: '5s',
                  },
                ],
                resources: {
                  requests: {
                    memory: '2Gi',
                  },
                },
                volumeMounts: [
                  {
                    name: 'export',
                    mountPath: '/export',
                  },
                ],
                livenessProbe: {
                  httpGet: {
                    path: '/minio/health/live',
                    port: 'http',
                    scheme: 'HTTP',
                  },
                  initialDelaySeconds: 5,
                  timeoutSeconds: 1,
                  periodSeconds: 5,
                  successThreshold: 1,
                  failureThreshold: 1,
                },
                readinessProbe: {
                  httpGet: {
                    path: '/minio/health/ready',
                    port: 'http',
                    scheme: 'HTTP',
                  },
                  initialDelaySeconds: 30,
                  timeoutSeconds: 6,
                  periodSeconds: 5,
                  successThreshold: 1,
                  failureThreshold: 3,
                },
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
                imagePullPolicy: 'IfNotPresent',
              },
            ],
            restartPolicy: 'Always',
            serviceAccountName: 'minio',
            securityContext: {
              runAsUser: 1000,
              runAsGroup: 1000,
              fsGroup: 1000,
            },
          },
        },
        strategy: {
          type: 'RollingUpdate',
          rollingUpdate: {
            maxUnavailable: 0,
            maxSurge: '100%',
          },
        },
      },
    },
    {
      kind: 'Service',
      apiVersion: 'v1',
      metadata: {
        name: 'minio',
        namespace: namespace,
        labels: {
          app: name,
        },
      },
      spec: {
        ports: [
          {
            name: 'http',
            protocol: 'TCP',
            port: 9000,
            targetPort: 9000,
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
