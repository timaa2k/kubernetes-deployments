---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traefik
  labels:
    name: traefik
  annotations:
spec:
  selector:
    matchLabels:
      name: traefik
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      annotations:
      labels:
        name: traefik
    spec:
      serviceAccountName: traefik
      terminationGracePeriodSeconds: 60
      hostNetwork: false
      containers:
      - image: traefik:2.2.8
        imagePullPolicy: IfNotPresent
        name: traefik
        resources:
        readinessProbe:
          httpGet:
            path: /ping
            port: 9000
          failureThreshold: 1
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 2
        livenessProbe:
          httpGet:
            path: /ping
            port: 9000
          failureThreshold: 3
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 2
        ports:
        - name: "traefik"
          containerPort: 9000
          protocol: "TCP"
        - name: "web"
          containerPort: 8000
          protocol: "TCP"
        - name: "websecure"
          containerPort: 8443
          protocol: "TCP"
        securityContext:
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsGroup: 1000
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
          - name: data
            mountPath: /data
            subPath:
          - name: tmp
            mountPath: /tmp
        args:
          - "--entryPoints.traefik.address=:9000/tcp"
          - "--entryPoints.web.address=:8000/tcp"
          - "--entryPoints.websecure.address=:8443/tcp"
          - "--api.dashboard=true"
          - "--ping=true"
          - "--providers.kubernetescrd"
          - "--providers.kubernetesingress"
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: traefik
        - name: tmp
          emptyDir: {}
      securityContext:
        fsGroup: 1000
---
apiVersion: v1
kind: List
items:
  - apiVersion: v1
    kind: Service
    metadata:
      name: traefik
      labels:
        name: traefik
      annotations:
    spec:
      type: NodePort
      selector:
        name: traefik
      ports:
      - port: 80
        name: web
        targetPort: "web"
        protocol: "TCP"
        nodePort: 30080
      - port: 443
        name: websecure
        targetPort: "websecure"
        protocol: "TCP"
        nodePort: 30443
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: traefik
  labels:
    name: traefik
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - traefik.containo.us
    resources:
      - ingressroutes
      - ingressroutetcps
      - ingressrouteudps
      - middlewares
      - tlsoptions
      - tlsstores
      - traefikservices
    verbs:
      - get
      - list
      - watch
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: traefik
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 128Mi
  hostPath:
    path: /mnt/hdd/cloud-config
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-backup-hdd
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: traefik
  namespace: traefik
  annotations:
    volume.beta.kubernetes.io/storage-class: local-backup-hdd
  labels:
    name: traefik
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 128Mi
  storageClassName: local-backup-hdd
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: traefik
  labels:
    name: traefik
  annotations:
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: traefik
  labels:
    name: traefik
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik
subjects:
  - kind: ServiceAccount
    name: traefik
    namespace: traefik
