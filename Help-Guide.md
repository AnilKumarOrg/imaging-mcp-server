# CAST Imaging MCP Server - Helm Chart Help Guide

## Overview

This Helm chart enables easy deployment and management of the CAST Imaging MCP (Model Context Protocol) server on Kubernetes clusters. The MCP server provides AI-powered access to CAST Imaging insights through a standardized protocol, enabling integration with AI tools and applications.

**Current Status**: ✅ **Fully Functional** - Chart version 1.1.0 with application version 3.4.4

## What is MCP Server?

The CAST Imaging MCP Server is a bridge between AI applications and CAST Imaging platform that:

- Exposes CAST Imaging data through Model Context Protocol (MCP)
- Provides access to applications, quality insights, security vulnerabilities, and architectural data
- Enables AI assistants to analyze software architecture and quality
- Supports real-time queries about software dependencies and structural flaws

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Configuration Guide](#configuration-guide)
4. [External Access Options](#external-access-options)
5. [Deployment Examples](#deployment-examples)
6. [Monitoring and Health](#monitoring-and-health)
7. [Troubleshooting](#troubleshooting)
8. [Upgrading](#upgrading)
9. [Advanced Configuration](#advanced-configuration)
10. [Uninstallation](#uninstallation)

## Prerequisites

### Software Requirements

- **Kubernetes**: Version 1.19+
- **Helm**: Version 3.8+
- **kubectl**: Configured to access your target cluster

### Cluster Requirements

- **CPU**: Minimum 200m per pod, recommended 1000m
- **Memory**: Minimum 512Mi per pod, recommended 2Gi
- **Storage**: Minimum 3Gi for persistent data and logs
- **Network**: Access to CAST Imaging services (console-control-panel)

### CAST Imaging Requirements

- **CAST Imaging Platform**: Running and accessible
- **Service Discovery**: IP address/hostname/FQDN of the machine on which the "imaging-services" component is installed (console-control-panel) available
- **Network Access**: Kubernetes cluster can reach CAST Imaging services

### Optional Components

- **Istio Service Mesh**: For VirtualService-based external access
- **NGINX Ingress Controller**: Alternative for external access
- **Cert-Manager**: For automatic TLS certificate management

## Quick Start

### 1. Basic Installation

The fastest way to get MCP server running:

```bash
# Clone or navigate to the chart directory
cd cast-imaging-mcp-server

# Install with default values (internal access only)
helm install imaging-mcp-server . --namespace mcp-server --create-namespace
```

### 2. Installation with External Access

For external access with Istio VirtualService:

```bash
# Install with external access enabled
helm install imaging-mcp-server . \
  --namespace mcp-server \
  --create-namespace \
  --set virtualService.enabled=true \
  --set virtualService.hosts='{mcp.your-domain.com}' \
  --set virtualService.gateways='{your-gateway-name}'
```

### 3. Verify Installation

```bash
# Check deployment status
kubectl get pods -n mcp-server

# View logs to confirm startup
kubectl logs -f deployment/imaging-mcp-server -n mcp-server

# Test connectivity (port-forward for local testing)
kubectl port-forward service/imaging-mcp-server 8282:8282 -n mcp-server
```

The server will be accessible at `http://localhost:8282/mcp` when using port-forward.

## Configuration Guide

### Essential Configuration Values

The chart uses a single `values.yaml` file with well-organized sections:

#### 1. Service Discovery (REQUIRED)

```yaml
# REQUIRED: Configure connection to CAST Imaging services
hostControlPanel: console-control-panel.castimagingv3.svc.cluster.local
portControlPanel: 8098
```

**Important**: These values MUST match your CAST Imaging environment:

- `hostControlPanel`: Control Panel service discovery endpoint
- `portControlPanel`: Port for Control Panel service (typically 8098)

#### 2. Container Image Configuration

```yaml
image:
  repository: "castimaging/imaging-mcp-server"
  tag: "3.4.4"                    # Latest stable version
  pullPolicy: "IfNotPresent"
```

#### 3. Resource Management

```yaml
resources:
  requests:
    cpu: 200m        # Minimum guaranteed CPU
    memory: 512Mi    # Minimum guaranteed memory
  limits:
    cpu: 1000m       # Maximum allowed CPU
    memory: 2Gi      # Maximum allowed memory
```

#### 4. Storage Configuration

```yaml
persistence:
  enabled: true                          # Enable persistent storage
  name: "imaging-mcp-server-pvc"        # PVC name (customize for multiple deployments)
  size: 3Gi                             # Storage size
  storageClass: "standard-rwo"          # Storage class (cloud-provider specific)
  accessMode: ReadWriteOnce             # Access mode
```

**Storage Classes by Cloud Provider:**

- **GCP**: `standard-rwo` (HDD) or `premium-rwo` (SSD)
- **AWS**: `gp2` or `gp3`
- **Azure**: `default` or `managed-premium`

#### 5. Application Settings

```yaml
config:
  imaging:
    pageSize: 1000              # API response page size
    displayPageSize: 20         # UI display page size
    code: "False"              # Enable code analysis features
  server:
    port: 8282                 # MCP server port
```

### External Access Options

The chart supports multiple ways to expose the MCP server externally:

### Option 1: Istio VirtualService

Best for environments with Istio service mesh:

```yaml
# In values.yaml
virtualService:
  enabled: true
  hosts:
    - "mcp.your-domain.com"
  gateways:
    - "istio-system/main-gateway"     # Your Istio gateway
```

**Deployment:**

```bash
helm install imaging-mcp-server . \
  --set virtualService.enabled=true \
  --set virtualService.hosts='{mcp.your-domain.com}' \
  --set virtualService.gateways='{istio-system/main-gateway}'
```

**Access URL:** `https://mcp.your-domain.com/mcp`

### Option 2: NGINX Ingress Controller

For standard Kubernetes ingress:

#### Step 1: Create Ingress Template

Create `templates/ingress.yaml`:

```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "cast-imaging-mcp.fullname" . }}
  labels:
    {{- include "cast-imaging-mcp.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "cast-imaging-mcp.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
```

#### Step 2: Configure Ingress in values.yaml

Add to your `values.yaml`:

```yaml
# NGINX Ingress Configuration
ingress:
  enabled: true                              # Enable ingress
  className: "nginx"                         # Ingress class
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # Optional: Rate limiting
    nginx.ingress.kubernetes.io/rate-limit-connections: "10"
    nginx.ingress.kubernetes.io/rate-limit-requests-per-minute: "60"
  hosts:
    - host: mcp.your-domain.com
      paths:
        - path: /mcp
          pathType: Prefix
  tls:
    - secretName: mcp-tls-secret            # TLS certificate secret
      hosts:
        - mcp.your-domain.com

# Disable VirtualService when using Ingress
virtualService:
  enabled: false
```

#### Step 3: Deploy with Ingress

```bash
# Install with NGINX ingress
helm install imaging-mcp-server . \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=mcp.your-domain.com \
  --set ingress.hosts[0].paths[0].path=/mcp \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set virtualService.enabled=false
```

#### Step 4: Set up TLS Certificate

**Option A: Manual Certificate**

```bash
# Create TLS secret with your certificate
kubectl create secret tls mcp-tls-secret \
  --cert=mcp.crt \
  --key=mcp.key \
  --namespace mcp-server
```

**Option B: Cert-Manager (Automatic)**

Add annotations for cert-manager:

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### Option 3: LoadBalancer Service

For cloud environments with load balancer support:

```yaml
# In values.yaml
service:
  type: LoadBalancer                        # Change from ClusterIP
  port: 8282
  targetPort: 8282
  # Optional: Specify load balancer IP
  # loadBalancerIP: "1.2.3.4"
```

**Note**: LoadBalancer service will expose the service directly without hostname-based routing.

### Option 4: NodePort Service

For on-premises or development environments:

```yaml
service:
  type: NodePort
  port: 8282
  targetPort: 8282
  nodePort: 32282                          # Optional: specify port (30000-32767)
```

Access via any cluster node: `http://node-ip:32282/mcp`

## Deployment Examples

### Example :

```bash
# Production deployment with HA
helm install mcp-prod . \
  --namespace mcp-production \
  --create-namespace \
  --set replicaCount=1 \
  --set resources.requests.cpu=500m \
  --set resources.requests.memory=1Gi \
  --set persistence.size=10Gi \
  --set virtualService.enabled=true \
  --set virtualService.hosts='{mcp.company.com}'
```

### Monitoring and Health

### Health Checks

The deployment includes comprehensive health checks using TCP probes:

#### Readiness Probe

```yaml
readinessProbe:
  tcpSocket:
    port: 8282
  initialDelaySeconds: 5          # Wait 5s before first check
  periodSeconds: 5                # Check every 5s
  timeoutSeconds: 3               # 3s timeout
  failureThreshold: 3             # Fail after 3 consecutive failures
```

#### Liveness Probe

```yaml
livenessProbe:
  tcpSocket:
    port: 8282
  initialDelaySeconds: 30         # Wait 30s before first check
  periodSeconds: 10               # Check every 10s
  timeoutSeconds: 5               # 5s timeout
  failureThreshold: 3             # Restart after 3 consecutive failures
```

#### Startup Probe

```yaml
startupProbe:
  tcpSocket:
    port: 8282
  initialDelaySeconds: 10         # Wait 10s before first check
  periodSeconds: 10               # Check every 10s
  failureThreshold: 30            # Allow 5 minutes for startup
```

### Monitoring Commands

#### Check Deployment Status

```bash
# Overall status
kubectl get all -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server

# Detailed pod status
kubectl describe pods -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server

# Check deployment rollout
kubectl rollout status deployment/imaging-mcp-server -n mcp-server
```

#### View Logs

```bash
# Current logs
kubectl logs deployment/imaging-mcp-server -n mcp-server

# Follow logs in real-time
kubectl logs -f deployment/imaging-mcp-server -n mcp-server

# View logs from all pods
kubectl logs -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server

# View logs with timestamps
kubectl logs deployment/imaging-mcp-server -n mcp-server --timestamps=true

# View previous container logs (if pod restarted)
kubectl logs deployment/imaging-mcp-server -n mcp-server --previous
```

#### Resource Usage

```bash
# View resource usage (requires metrics-server)
kubectl top pods -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server

# Describe deployment for resource limits
kubectl describe deployment imaging-mcp-server -n mcp-server
```

### Service Health Verification

#### Test MCP Server Functionality

```bash
# Port forward for local testing
kubectl port-forward service/imaging-mcp-server 8282:8282 -n mcp-server

# Test MCP endpoint (in another terminal)
curl -v http://localhost:8282/mcp
```

Expected response should include MCP protocol errors (405 Method Not Allowed for GET requests is normal).

#### Internal Connectivity Test

```bash
# Test from within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -n mcp-server -- sh

# Inside the pod:
wget -qO- imaging-mcp-server:8282/mcp || echo "Connection test complete"
```

### Application Logs Analysis

The MCP server provides detailed logs. Key log patterns to monitor:

#### Successful Startup

```
INFO     Starting MCP server 'imaging' with transport 'streamable-http' on http://0.0.0.0:8282/mcp
INFO     Started server process [1]
INFO     Application startup complete.
INFO     Uvicorn running on http://0.0.0.0:8282
```

#### Successful API Calls

```
INFO     100.114.1.67:44568 - "POST /mcp HTTP/1.1" 200 OK
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Pod Stuck in Pending State

**Symptoms:**

```bash
kubectl get pods -n mcp-server
NAME                                 READY   STATUS    RESTARTS   AGE
imaging-mcp-server-xxx               0/1     Pending   0          5m
```

**Diagnosis:**

```bash
kubectl describe pod imaging-mcp-server-xxx -n mcp-server
```

**Common Causes and Solutions:**

**Insufficient Resources:**

```bash
# Check node resources
kubectl describe nodes

# Solution: Reduce resource requests
helm upgrade imaging-mcp-server . \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=256Mi
```

**Storage Issues:**

```bash
# Check PVC status
kubectl get pvc -n mcp-server

# Check storage classes
kubectl get storageclass

# Solution: Use available storage class
helm upgrade imaging-mcp-server . \
  --set persistence.storageClass=standard
```

**Node Selector Issues:**

```bash
# Check node labels
kubectl get nodes --show-labels

# Solution: Remove node selectors or fix labels
helm upgrade imaging-mcp-server . \
  --set nodeSelector={}
```

#### 2. Container CrashLoopBackOff

**Symptoms:**

```bash
kubectl get pods -n mcp-server
NAME                                 READY   STATUS             RESTARTS   AGE
imaging-mcp-server-xxx               0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**

```bash
# Check container logs
kubectl logs imaging-mcp-server-xxx -n mcp-server

# Check previous container logs
kubectl logs imaging-mcp-server-xxx -n mcp-server --previous

# Check pod events
kubectl describe pod imaging-mcp-server-xxx -n mcp-server
```

**Common Solutions:**

**Image Issues:**

```bash
# Verify image exists and is pullable
docker pull castimaging/imaging-mcp-server:3.4.4

# Solution: Use correct image tag
helm upgrade imaging-mcp-server . \
  --set image.tag=3.4.4
```

**Configuration Issues:**

```bash
# Check if CAST Imaging services are accessible
kubectl exec -it imaging-mcp-server-xxx -n mcp-server -- nslookup console-control-panel.castimagingv3.svc.cluster.local

# Solution: Fix service discovery configuration
helm upgrade imaging-mcp-server . \
  --set hostControlPanel=your-correct-hostname \
  --set portControlPanel=8098
```

**Permissions Issues:**

```bash
# Solution: Adjust security context
helm upgrade imaging-mcp-server . \
  --set podSecurityContext.fsGroup=0 \
  --set securityContext.runAsUser=0
```

#### 3. Service Not Accessible

**Symptoms:**

- External access fails
- Port forwarding doesn't work
- Service exists but can't be reached

**Diagnosis:**

```bash
# Check service status
kubectl get service imaging-mcp-server -n mcp-server

# Check endpoints
kubectl get endpoints imaging-mcp-server -n mcp-server

# Check if pods are running and ready
kubectl get pods -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server
```

**Solutions:**

**Service Selector Mismatch:**

```bash
# Check service selector matches pod labels
kubectl describe service imaging-mcp-server -n mcp-server
kubectl get pods --show-labels -n mcp-server

# Verify in values.yaml that selector labels are correct
```

**Port Configuration Issues:**

```bash
# Check if service ports match container ports
kubectl describe deployment imaging-mcp-server -n mcp-server

# Solution: Ensure port consistency
helm upgrade imaging-mcp-server . \
  --set service.port=8282 \
  --set service.targetPort=8282
```

#### 4. External Access Not Working

**For Istio VirtualService:**

```bash
# Check if VirtualService is created
kubectl get virtualservice -n mcp-server

# Check VirtualService configuration
kubectl describe virtualservice imaging-mcp-server -n mcp-server

# Check if gateway exists
kubectl get gateway -A | grep your-gateway-name

# Test internal service first
kubectl port-forward service/imaging-mcp-server 8282:8282 -n mcp-server
```

**For NGINX Ingress:**

```bash
# Check if ingress is created
kubectl get ingress -n mcp-server

# Check ingress status
kubectl describe ingress imaging-mcp-server -n mcp-server

# Check NGINX ingress controller logs
kubectl logs -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx

# Verify DNS resolution
nslookup mcp.your-domain.com
```

#### 5. MCP Protocol Errors

**Symptoms:**

- Client connections fail
- Getting protocol-related errors

**Common MCP Client Errors and Solutions:**

**404 Status Sending Message:**

```
Client logs show "404 status sending message"
```

**Solution**: Verify the MCP endpoint URL includes `/mcp` path:

- Correct: `https://mcp.your-domain.com/mcp`
- Wrong: `https://mcp.your-domain.com/`

**Connection Timeout:**

```
Client logs show connection timeouts
```

**Solution**: Check network connectivity and firewall rules.

**Certificate Errors:**

```
TLS/SSL certificate verification failed
```

**Solution**: Ensure proper TLS certificate configuration in ingress/VirtualService.

### Debug Commands Collection

#### Comprehensive Status Check Script

Create `debug-mcp.sh`:

```bash
#!/bin/bash
NAMESPACE=${1:-mcp-server}
echo "=== CAST Imaging MCP Server Debug Info ==="
echo "Namespace: $NAMESPACE"
echo

echo "1. Helm Release Status:"
helm list -n $NAMESPACE | grep imaging-mcp-server
echo

echo "2. Pod Status:"
kubectl get pods -l app.kubernetes.io/name=cast-imaging-mcp-server -n $NAMESPACE -o wide
echo

echo "3. Deployment Status:"
kubectl get deployment imaging-mcp-server -n $NAMESPACE
echo

echo "4. Service Status:"
kubectl get service imaging-mcp-server -n $NAMESPACE
echo

echo "5. Endpoints:"
kubectl get endpoints imaging-mcp-server -n $NAMESPACE
echo

echo "6. PVC Status:"
kubectl get pvc -n $NAMESPACE
echo

echo "7. Recent Events:"
kubectl get events --sort-by=.metadata.creationTimestamp -n $NAMESPACE | tail -10
echo

echo "8. Resource Usage (if metrics available):"
kubectl top pods -l app.kubernetes.io/name=cast-imaging-mcp-server -n $NAMESPACE 2>/dev/null || echo "Metrics not available"
echo

echo "9. VirtualService Status:"
kubectl get virtualservice -n $NAMESPACE 2>/dev/null || echo "No VirtualService found"
echo

echo "10. Ingress Status:"
kubectl get ingress -n $NAMESPACE 2>/dev/null || echo "No Ingress found"

echo "=== Debug Info Complete ==="
```

**Usage:**

```bash
chmod +x debug-mcp.sh
./debug-mcp.sh mcp-server
```

#### Log Collection Script

Create `collect-mcp-logs.sh`:

```bash
#!/bin/bash
NAMESPACE=${1:-mcp-server}
OUTPUT_DIR="mcp-logs-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$OUTPUT_DIR"
echo "Collecting MCP server diagnostics in: $OUTPUT_DIR"

# Helm information
helm get values imaging-mcp-server -n $NAMESPACE > "$OUTPUT_DIR/helm-values.yaml" 2>&1
helm status imaging-mcp-server -n $NAMESPACE > "$OUTPUT_DIR/helm-status.txt" 2>&1

# Kubernetes resources
kubectl get all -l app.kubernetes.io/name=cast-imaging-mcp-server -n $NAMESPACE -o yaml > "$OUTPUT_DIR/k8s-resources.yaml"
kubectl describe deployment imaging-mcp-server -n $NAMESPACE > "$OUTPUT_DIR/deployment-describe.txt" 2>&1

# Logs
kubectl logs -l app.kubernetes.io/name=cast-imaging-mcp-server -n $NAMESPACE --tail=1000 > "$OUTPUT_DIR/application.log" 2>&1

# Events
kubectl get events --sort-by=.metadata.creationTimestamp -n $NAMESPACE > "$OUTPUT_DIR/events.txt"

# Network
kubectl get service,endpoints,ingress,virtualservice -n $NAMESPACE > "$OUTPUT_DIR/networking.txt" 2>&1

echo "Diagnostics collected in: $OUTPUT_DIR"
echo "Share this directory with support team if needed."
```

**Usage:**

```bash
chmod +x collect-mcp-logs.sh
./collect-mcp-logs.sh mcp-server
```

## Upgrading

### Before You Upgrade

1. **Backup Current Configuration:**

```bash
# Export current values
helm get values imaging-mcp-server -n mcp-server > current-values.yaml

# Backup persistent data (optional)
kubectl exec deployment/imaging-mcp-server -n mcp-server -- \
  tar czf /tmp/pre-upgrade-backup.tar.gz /app/storage
```

2. **Check Compatibility:**

```bash
# Check current version
helm list -n mcp-server

# Check image compatibility
docker pull castimaging/imaging-mcp-server:3.4.4
```

### Upgrade Process

#### 1. Standard Upgrade

```bash
# Navigate to chart directory
cd cast-imaging-mcp-server

# Upgrade with current values
helm upgrade imaging-mcp-server . -n mcp-server
```

#### 2. Upgrade with New Configuration

```bash
# Upgrade with new values file
helm upgrade imaging-mcp-server . \
  -n mcp-server \
  -f values-new.yaml

# Or upgrade with specific value changes
helm upgrade imaging-mcp-server . \
  -n mcp-server \
  --set image.tag=3.4.4 \
  --set persistence.size=5Gi
```

#### 3. Safe Upgrade with Rollback Protection

```bash
# Upgrade with automatic rollback on failure
helm upgrade imaging-mcp-server . \
  -n mcp-server \
  --atomic \
  --wait \
  --timeout=10m
```

#### 4. Preview Changes Before Upgrade

```bash
# Dry run to see what would change
helm upgrade imaging-mcp-server . \
  -n mcp-server \
  --dry-run \
  --debug
```

### Monitor Upgrade Progress

```bash
# Watch rollout status
kubectl rollout status deployment/imaging-mcp-server -n mcp-server

# Monitor pods during upgrade
kubectl get pods -w -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server
```

### Verify Upgrade

```bash
# Check new version
helm list -n mcp-server

# Test functionality
kubectl port-forward service/imaging-mcp-server 8282:8282 -n mcp-server
# Test in browser: http://localhost:8282/mcp

# Check logs for errors
kubectl logs deployment/imaging-mcp-server -n mcp-server --tail=100
```

### Rollback if Needed

```bash
# View rollout history
helm history imaging-mcp-server -n mcp-server

# Rollback to previous version
helm rollback imaging-mcp-server -n mcp-server

# Rollback to specific revision
helm rollback imaging-mcp-server 5 -n mcp-server
```

### Uninstallation

### Complete Removal Process

#### 1. Backup Data (Optional)

```bash
# Create final backup of persistent data
kubectl exec deployment/imaging-mcp-server -n mcp-server -- \
  tar czf /tmp/final-backup.tar.gz /app/storage

# Copy backup to local machine
kubectl cp mcp-server/imaging-mcp-server-xxx:/tmp/final-backup.tar.gz ./final-backup.tar.gz
```

#### 2. Uninstall Helm Release

```bash
# Standard uninstall (keeps PVC)
helm uninstall imaging-mcp-server -n mcp-server
```

#### 3. Remove Persistent Volumes (if desired)

```bash
# List PVCs (these are NOT automatically deleted)
kubectl get pvc -n mcp-server

# Delete specific PVC
kubectl delete pvc imaging-mcp-server-pvc -n mcp-server

# Or delete all PVCs in namespace
kubectl delete pvc --all -n mcp-server
```

#### 4. Clean Up External Resources

```bash
# Remove ingress (if created separately)
kubectl delete ingress imaging-mcp-server -n mcp-server

# Remove network policies (if created)
kubectl delete networkpolicy -l app.kubernetes.io/name=cast-imaging-mcp-server -n mcp-server

# Remove secrets (TLS certificates, etc.)
kubectl delete secret mcp-tls-secret -n mcp-server
```

#### 5. Remove Namespace (if dedicated)

```bash
# If using dedicated namespace, remove everything at once
kubectl delete namespace mcp-server
```

#### 6. Verify Complete Removal

```bash
# Check for remaining resources
kubectl get all -l app.kubernetes.io/name=cast-imaging-mcp-server --all-namespaces
kubectl get pvc -l app.kubernetes.io/name=cast-imaging-mcp-server --all-namespaces
```

### Selective Cleanup Options

#### Keep Data, Remove Application

```bash
# Remove application but keep storage for future use
helm uninstall imaging-mcp-server -n mcp-server

# Verify PVC is retained
kubectl get pvc -n mcp-server
```

#### Remove Application, Keep Configuration

```bash
# Export configuration before removal
helm get values imaging-mcp-server -n mcp-server > backup-values.yaml

# Remove application
helm uninstall imaging-mcp-server -n mcp-server
kubectl delete pvc --all -n mcp-server

# Configuration can be reused later with:
# helm install imaging-mcp-server . -f backup-values.yaml -n mcp-server
```

---

## Chart Information

- **Chart Name**: cast-imaging-mcp-server
- **Chart Version**: 1.1.0
- **Application Version**: 3.4.4
- **Last Updated**: September 26, 2025
