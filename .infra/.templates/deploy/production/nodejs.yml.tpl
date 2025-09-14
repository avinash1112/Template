apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-nodejs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend-nodejs
  template:
    metadata:
      labels:
        app: frontend-nodejs
    spec:
      containers:
      - name: nginx
        image: your-registry/frontend-nodejs:production
        env:
        - name: NODE_ENV
          value: "production"
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
        volumeMounts:
        # Option 1: Use certificates from image (built-in)
        # No additional mounts needed
        
        # Option 2: Override with Kubernetes secrets (recommended for rotation)
        - name: tls-certs
          mountPath: /opt/nodejs/certs
          readOnly: true
        livenessProbe:
          exec:
            command: ["/usr/local/bin/liveness.sh"]
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["/usr/local/bin/readiness.sh"]
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      # Option 2: Kubernetes secret volume (for certificate rotation)
      - name: tls-certs
        secret:
          secretName: frontend-nodejs-tls
          items:
          - key: tls.crt
            path: server.crt
          - key: tls.key
            path: server.key
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodejs
spec:
  selector:
    app: frontend-nodejs
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 443
    targetPort: 443
    name: https
  type: ClusterIP
---
# TLS Secret (managed by cert-manager or manually created)
apiVersion: v1
kind: Secret
metadata:
  name: frontend-nodejs-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>