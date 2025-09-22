# CAST Imaging MCP Server - Helm Chart Help Guide

## Overview

This Helm chart enables easy deployment and management of the CAST Imaging MCP server on Kubernetes clusters, with support for persistent storage, security contexts, and external access.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Deployment Examples](#deployment-examples)
5. [Storage Management](#storage-management)
6. [External Access](#external-access)
7. [Monitoring and Health](#monitoring-and-health)
8. [Troubleshooting](#troubleshooting)
9. [Upgrading](#upgrading)
10. [Uninstallation](#uninstallation)

## Prerequisites

### Software Requirements

- **Kubernetes**: Version 1.19+
- **Helm**: Version 3.8+
- **kubectl**: Configured to access your target cluster

### Cluster Requirements

- **Storage**: Support for PersistentVolumes with ReadWriteOnce access mode
- **CPU**: Minimum 500m per pod
- **Memory**: Minimum 1Gi per pod
- **Storage**: Minimum 2Gi for persistent data

### Optional Components

- **Istio Service Mesh**: For advanced external access and traffic management
- **Ingress Controller**: Alternative to Istio for external access

## Installation

### Quick Start

1. **Install from Local Chart** (recommended for current deployment):

   ```bash
   # Navigate to the chart directory
   cd cast-imaging-mcp

   # Install with default configuration
   helm install imaging-mcp-server .
   ```
2. **Install with Custom Configuration**:

   ```bash
   helm install imaging-mcp-server . -f values-custom.yaml
   ```

## Configuration

### Core Configuration Values

The chart supports extensive configuration through values. Here are the key sections:

#### Application Configuration

```yaml
# Basic application settings
image:
  repository: castsoftware/imaging-mcp-server
  tag: "3.4.3"
  pullPolicy: IfNotPresent

# Service configuration  
service:
  type: ClusterIP
  port: 8282
  targetPort: 8282

# Name overrides
nameOverride: ""
fullnameOverride: "imaging-mcp-server"
```

#### Resource Management

```yaml
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

#### Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65534
  runAsGroup: 65534
  fsGroup: 65534

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 65534
```

#### Persistence Configuration

```yaml
persistence:
  enabled: true
  storageClassName: "standard-rwo"
  accessMode: ReadWriteOnce
  size: 5Gi
```

**Note**: The chart now uses a simplified single PVC approach with an init container that creates organized subdirectories for different data types. This provides better resource utilization and easier management compared to separate PVCs.

### Chart Optimizations (v1.1.0-beta1)

This version of the chart has been optimized for better security and simplicity:

#### **Simplified Storage:**

- **Single PVC**: Consolidated from multiple PVC options to a single 5Gi PVC with organized subdirectories
- **Init Container**: Automatically creates required directory structure (`/app/storage/data/` and `/app/storage/logs/`)
- **Better Resource Utilization**: Single storage allocation instead of multiple smaller PVCs

#### **Deployed Resources:**

The chart now creates exactly **4 Kubernetes resources**:

1. **Deployment**: Manages the MCP server pod
2. **Service**: Exposes the application on port 8282
3. **PersistentVolumeClaim**: Single Gi storage volume
4. **ReplicaSet**: Created automatically by the Deployment

### Environment-Specific Values Files

#### values-gcp-customername.yaml

Optimized for customer GCP environment with:

- Single PVC storage configuration
- Specific naming for service discovery
- Integration with existing VirtualService
- GCP-optimized storage classes

#### values-development.yaml (example)

```yaml
image:
  tag: latest
  pullPolicy: Always

persistence:
  enabled: false

resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi

# Enable debug logging
env:
  - name: LOG_LEVEL
    value: "DEBUG"
```

## Deployment Examples

### Basic Development Deployment

```bash
# Create namespace
kubectl create namespace mcp-dev

# Deploy with minimal resources
helm install mcp-dev . \
  --namespace mcp-dev \
  --set persistence.enabled=false \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=512Mi
```

## Storage Management

### Single PVC Approach (Current Implementation)

The chart uses a consolidated storage approach with a single PVC and organized subdirectories:

```yaml
persistence:
  enabled: true
  size: 5Gi
  storageClassName: "standard-rwo"
```

**Storage Structure:**

```
/app/storage/
├── data/          # Application data
├── logs/          # Application logs
└── lost+found/    # File system recovery
```

### Storage Class Examples

#### Google Cloud Platform

```yaml
persistence:
  storageClassName: "standard-rwo"    # Standard persistent disk
  # or "premium-rwo" for SSD performance
```

#### Amazon EKS

```yaml
persistence:
  storageClassName: "gp2"             # General purpose SSD
  # or "gp3" for latest generation
```

#### Azure AKS

```yaml
persistence:
  storageClassName: "default"         # Standard managed disk
  # or "managed-premium" for premium SSD
```

## External Access

### Using Istio VirtualService

If you have Istio service mesh installed, you can use VirtualService for external access:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: imaging-mcp-server
  namespace: cast-imaging-mcp-server
spec:
  hosts:
  - mcp-server.your-domain.com
  http:
  - match:
    - uri:
        prefix: /mcp
    route:
    - destination:
        host: mcp-server.your-domain.com
        port:
          number: 8282
```

### Using Kubernetes Ingress

For standard ingress controllers:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: imaging-mcp-server
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: mcp-server.your-domain.com
    http:
      paths:
      - path: /mcp
        pathType: Prefix
        backend:
          service:
            name: imaging-mcp-server
            port:
              number: 8282
```

### Port Forwarding for Development

For local development and testing:

```bash
# Forward local port 8282 to service
kubectl port-forward service/imaging-mcp-server 8282:8282

# Access at http://localhost:8282
```

## Monitoring and Health

### Health Checks

The deployment includes comprehensive health checks:

#### Readiness Probe

```yaml
readinessProbe:
  tcpSocket:
    port: 8282
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

#### Liveness Probe

```yaml
livenessProbe:
  tcpSocket:
    port: 8282
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
```

### Monitoring Commands

#### Check Pod Status

```bash
# View pod status
kubectl get pods -l app.kubernetes.io/name=cast-imaging-mcp

# Describe pod for detailed status
kubectl describe pod -l app.kubernetes.io/name=cast-imaging-mcp
```

#### View Logs

```bash
# View current logs
kubectl logs -l app.kubernetes.io/name=cast-imaging-mcp

# Follow logs in real-time
kubectl logs -l app.kubernetes.io/name=cast-imaging-mcp -f

# View logs from specific container
kubectl logs deployment/imaging-mcp-server -c mcp-server
```

#### Check Resource Usage

```bash
# View resource usage
kubectl top pods -l app.kubernetes.io/name=cast-imaging-mcp

# Detailed resource description
kubectl describe deployment imaging-mcp-server
```

### Service Health Verification

#### Test Service Connectivity

```bash
# Test service connectivity from within cluster
kubectl run test-pod --image=alpine --rm -it -- sh
# Inside the pod:
# wget -qO- imaging-mcp-server:8282 || echo "Connection failed"
```

#### External Health Check

```bash
 If using external access
curl -I https://mcp-server.your-domain.com/mcp
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Pod Stuck in Pending State

**Symptoms:**

```bash
kubectl get pods
NAME                                    READY   STATUS    RESTARTS   AGE
imaging-mcp-server-xxx                  0/1     Pending   0          5m
```

**Possible Causes and Solutions:**

**Insufficient Resources:**

```bash
# Check node resources
kubectl describe nodes

# Solution: Reduce resource requests or add more nodes
helm upgrade imaging-mcp-server ./cast-imaging-mcp \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=512Mi
```

**Storage Issues:**

```bash
# Check PVC status
kubectl get pvc

# Check available storage classes
kubectl get storageclass

# Solution: Fix storage class or create PV manually
```

#### 2. Container Failing to Start

**Symptoms:**

```bash
kubectl get pods
NAME                                    READY   STATUS             RESTARTS   AGE
imaging-mcp-server-xxx                  0/1     CrashLoopBackOff   3          5m
```

**Debugging Steps:**

```bash
# Check container logs
kubectl logs imaging-mcp-server-xxx

# Check events
kubectl describe pod imaging-mcp-server-xxx

# Common solutions:
# - Fix image tag
# - Adjust security context
# - Check volume mounts
```

**Permission Issues:**

```bash
# Check if security context is preventing file access
kubectl exec -it imaging-mcp-server-xxx -- ls -la /persistent-data

# Solution: Adjust fsGroup or runAsUser
helm upgrade imaging-mcp-server ./cast-imaging-mcp \
  --set podSecurityContext.fsGroup=0
```

#### 3. Service Not Accessible

**Symptoms:**

- Service exists but cannot be reached
- External access fails

**Debugging Steps:**

```bash
# Check service status
kubectl get service imaging-mcp-server

# Check endpoints
kubectl get endpoints imaging-mcp-server

# Test service within cluster
kubectl run debug --image=alpine --rm -it -- sh
# wget -qO- imaging-mcp-server:8282
```

**Common Solutions:**

```bash
# Check service selector matches pod labels
kubectl get pods --show-labels
kubectl describe service imaging-mcp-server

# Verify port configuration
helm upgrade imaging-mcp-server ./cast-imaging-mcp \
  --set service.port=8282 \
  --set service.targetPort=8282
```

#### 4. Persistence Issues

**Storage Not Mounting:**

```bash
# Check PVC status
kubectl get pvc

# Check PV binding
kubectl get pv

# Describe PVC for events
kubectl describe pvc cast-storage
```

**Data Not Persisting:**

```bash
# Verify volume mounts
kubectl describe pod imaging-mcp-server-xxx

# Check if data is written to correct path
kubectl exec -it imaging-mcp-server-xxx -- ls -la /app/storage
```

#### 5. External Access Issues

**Istio VirtualService Not Working:**

```bash
# Check VirtualService configuration
kubectl get virtualservice imaging-mcp-server -o yaml

# Check Istio gateway
kubectl get gateway -A

# Test internal service first
kubectl port-forward service/imaging-mcp-server 8282:8282
```

### Debug Commands Reference

#### Comprehensive Status Check

```bash
#!/bin/bash
echo "=== CAST Imaging MCP Server Status ==="
echo

echo "1. Helm Release Status:"
helm list -A | grep imaging-mcp-server

echo -e "\n2. Pod Status:"
kubectl get pods -l app.kubernetes.io/name=cast-imaging-mcp -o wide

echo -e "\n3. Service Status:"
kubectl get services -l app.kubernetes.io/name=cast-imaging-mcp

echo -e "\n4. PVC Status:"
kubectl get pvc -l app.kubernetes.io/name=cast-imaging-mcp

echo -e "\n5. Recent Events:"
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10

echo -e "\n6. Resource Usage:"
kubectl top pods -l app.kubernetes.io/name=cast-imaging-mcp 2>/dev/null || echo "Metrics server not available"
```

#### Log Collection Script

```bash
#!/bin/bash
NAMESPACE=${1:-default}
OUTPUT_DIR="./mcp-server-logs-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$OUTPUT_DIR"

echo "Collecting CAST Imaging MCP Server diagnostics..."

# Helm status
helm status imaging-mcp-server > "$OUTPUT_DIR/helm-status.txt" 2>&1

# Pod information
kubectl get pods -l app.kubernetes.io/name=cast-imaging-mcp -o yaml > "$OUTPUT_DIR/pods.yaml"
kubectl describe pods -l app.kubernetes.io/name=cast-imaging-mcp > "$OUTPUT_DIR/pods-describe.txt"

# Service information
kubectl get services -l app.kubernetes.io/name=cast-imaging-mcp -o yaml > "$OUTPUT_DIR/services.yaml"

# PVC information
kubectl get pvc -l app.kubernetes.io/name=cast-imaging-mcp -o yaml > "$OUTPUT_DIR/pvc.yaml"

# Logs
kubectl logs -l app.kubernetes.io/name=cast-imaging-mcp --tail=1000 > "$OUTPUT_DIR/application-logs.txt" 2>&1

# Events
kubectl get events --sort-by=.metadata.creationTimestamp > "$OUTPUT_DIR/events.txt"

echo "Diagnostics collected in: $OUTPUT_DIR"
```

## Upgrading

### Upgrade Process

#### 1. Check Current Version

```bash
helm list
helm get values imaging-mcp-server
```

#### 2. Backup Current Configuration

```bash
# Export current values
helm get values imaging-mcp-server > current-values.yaml

# Backup persistent data (if applicable)
kubectl exec deployment/imaging-mcp-server -- \
  tar czf /tmp/pre-upgrade-backup.tar.gz /persistent-data
```

#### 3. Perform Upgrade

**Standard Upgrade:**

```bash
helm upgrade imaging-mcp-server .
```

**Upgrade with New Values:**

```bash
helm upgrade imaging-mcp-server . \
  -f values-gcp-customer.yaml \
  --set image.tag=3.4.4
```

**Upgrade with Wait and Timeout:**

```bash
helm upgrade imaging-mcp-server . \
  --wait \
  --timeout=10m \
  --atomic  # Rollback on failure
```

#### 4. Verify Upgrade

```bash
# Check rollout status
kubectl rollout status deployment/imaging-mcp-server

# Verify functionality
kubectl port-forward service/imaging-mcp-server 8282:8282
# Test at http://localhost:8282
```

### Rollback if Needed

```bash
# View rollout history
helm history imaging-mcp-server

# Rollback to previous version
helm rollback imaging-mcp-server

# Rollback to specific revision
helm rollback imaging-mcp-server 2
```

### Version-Specific Upgrade Notes

#### Upgrading from 1.0.x to 1.1.x

- **Breaking Change**: Storage configuration unified to single PVC by default
- **Action Required**: Review storage settings in values file
- **Migration**: Data automatically preserved during upgrade

#### Upgrading Image Versions

```bash
# Always verify image compatibility
helm upgrade imaging-mcp-server . \
  --set image.tag=3.4.4 \
  --dry-run

# Apply upgrade
helm upgrade imaging-mcp-server . \
  --set image.tag=3.4.4
```

## Uninstallation

### Clean Uninstall Process

#### 1. Backup Data (Optional)

```bash
# Create final backup
kubectl exec deployment/imaging-mcp-server -- \
  tar czf /tmp/final-backup.tar.gz /app/storage

kubectl cp platform-services-glb-castaip/imaging-mcp-server-xxx:/tmp/final-backup.tar.gz ./final-backup.tar.gz
```

#### 2. Remove Helm Release

```bash
# Standard uninstall
helm uninstall imaging-mcp-server

# Uninstall from specific namespace
helm uninstall imaging-mcp-server --namespace mcp-server
```

#### 3. Clean Up Persistent Volumes (if desired)

```bash
# List PVCs (these are NOT automatically deleted)
kubectl get pvc

# Delete PVC to free storage
kubectl delete pvc imaging-mcp-server-storage

# Or delete all PVCs with the app label
kubectl delete pvc -l app.kubernetes.io/name=cast-imaging-mcp
```

#### 4. Clean Up Namespace (if dedicated)

```bash
# If using dedicated namespace
kubectl delete namespace mcp-server
```

#### 5. Verify Clean Removal

```bash
# Check for remaining resources
kubectl get all -l app.kubernetes.io/name=cast-imaging-mcp
kubectl get pvc -l app.kubernetes.io/name=cast-imaging-mcp
```

### Selective Cleanup

#### Keep Data, Remove Application

```bash
# Uninstall but keep PVCs
helm uninstall imaging-mcp-server

# PVC remains for future reinstallation
kubectl get pvc  # Should still show imaging-mcp-server-storage
```

#### Remove Everything

```bash
# Complete removal including data
helm uninstall imaging-mcp-server
kubectl delete pvc -l app.kubernetes.io/name=cast-imaging-mcp
```

## Advanced Configuration

### Multi-Environment Setup

#### Directory Structure

```
environments/
├── development/
│   ├── values-dev.yaml
│   └── secrets-dev.yaml
├── staging/
│   ├── values-staging.yaml
│   └── secrets-staging.yaml
└── production/
    ├── values-prod.yaml
    └── secrets-prod.yaml
```

#### Deployment Script

```bash
#!/bin/bash
ENVIRONMENT=${1:-development}
NAMESPACE="mcp-${ENVIRONMENT}"

echo "Deploying to ${ENVIRONMENT} environment..."

helm upgrade --install "mcp-${ENVIRONMENT}" . \
  -f "environments/${ENVIRONMENT}/values-${ENVIRONMENT}.yaml" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait
```

### Security Hardening

#### Enhanced Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65534
  runAsGroup: 65534
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 65534
  seccompProfile:
    type: RuntimeDefault
```

#### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: imaging-mcp-server-netpol
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: cast-imaging-mcp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    ports:
    - protocol: TCP
      port: 8282
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS outbound
    - protocol: UDP
      port: 53   # DNS
```

### Documentation Links

- [CAST Imaging Official Documentation](https://doc.castsoftware.com/display/IMAGING)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

#### **Chart Version**: 1.1.0-beta1

**Application Version**: 3.4.3
**Last Updated**: September 18, 2025
**Maintainer**: CAST Delivery Team
