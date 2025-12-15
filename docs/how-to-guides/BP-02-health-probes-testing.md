# BP-02: Kubernetes Health Probes - Testing Guide

## Overview

This guide provides hands-on testing procedures for the health probes configured in the Podinfo deployment. You'll learn how each probe type works and their impact on pod lifecycle management.

## Health Probe Configuration Summary

### Startup Probe
- **Endpoint**: `/healthz`
- **Purpose**: Allows up to 60 seconds for application initialization
- **Configuration**: Checks every 5 seconds, fails after 12 consecutive failures
- **Impact**: Delays liveness/readiness checks until startup succeeds

### Liveness Probe
- **Endpoint**: `/healthz`
- **Purpose**: Detects if the application is running properly
- **Configuration**: Checks every 10 seconds, restarts after 3 consecutive failures (30s)
- **Impact**: Kubelet restarts the container on failure

### Readiness Probe
- **Endpoint**: `/readyz`
- **Purpose**: Determines if the pod should receive traffic
- **Configuration**: Checks every 5 seconds, marks not ready after 3 consecutive failures (15s)
- **Impact**: Pod is removed from service endpoints on failure

## Testing Procedures

### Test 1: Verify Initial Deployment

Deploy the updated configuration and verify all probes are passing:

```bash
# Apply the configuration
kubectl apply -k k8s-manifests/base/podinfo

# Watch pod status
kubectl get pods -l app=podinfo -w

# Check probe status in pod description
kubectl describe pod -l app=podinfo | grep -A 10 "Liveness\|Readiness\|Startup"
```

**Expected Outcome**: All pods should reach `Running` status with `2/2` containers ready.

### Test 2: Verify Probe Endpoints

Test that the health check endpoints are responding correctly:

```bash
# Get a pod name
POD_NAME=$(kubectl get pod -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Test healthz endpoint (liveness)
kubectl exec $POD_NAME -- wget -qO- http://localhost:9898/healthz

# Test readyz endpoint (readiness)
kubectl exec $POD_NAME -- wget -qO- http://localhost:9898/readyz

# View full runtime information
kubectl exec $POD_NAME -- wget -qO- http://localhost:9898/
```

**Expected Outcome**: Both endpoints should return HTTP 200 OK with JSON responses.

### Test 3: Readiness Probe - Traffic Draining

Test controlled traffic removal using the `/readyz/disable` endpoint:

```bash
# Get service endpoint
kubectl get svc podinfo

# Port forward to access the service
kubectl port-forward svc/podinfo 9898:9898 &
PF_PID=$!

# Verify pod is receiving traffic
curl http://localhost:9898/

# Get a pod name
POD_NAME=$(kubectl get pod -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Disable readiness (pod will stop receiving traffic)
kubectl exec $POD_NAME -- wget -qO- -S --method=POST http://localhost:9898/readyz/disable

# Watch the pod become not ready
kubectl get pods -l app=podinfo -w
# You should see READY change from 1/1 to 0/1

# Check endpoints (pod should be removed)
kubectl get endpoints podinfo

# Re-enable readiness
kubectl exec $POD_NAME -- wget -qO- -S --method=POST http://localhost:9898/readyz/enable

# Watch pod become ready again
kubectl get pods -l app=podinfo -w

# Cleanup port-forward
kill $PF_PID
```

**Expected Outcome**: 
- After disable: Pod shows `0/1` ready, removed from endpoints
- After enable: Pod shows `1/1` ready, added back to endpoints
- Other pods continue serving traffic throughout

**Use Case**: Graceful maintenance, controlled traffic draining during updates

### Test 4: Liveness Probe - Container Restart

Test automatic container restart when liveness probe fails:

```bash
# Get a pod name
POD_NAME=$(kubectl get pod -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Check current restart count
kubectl get pod $POD_NAME

# Trigger a panic (causes immediate container crash)
kubectl exec $POD_NAME -- wget -qO- http://localhost:9898/panic || echo "Pod crashed as expected"

# Watch for automatic restart
kubectl get pods -l app=podinfo -w
# You should see the container restart

# Check restart count (should be incremented)
kubectl get pod $POD_NAME

# View restart events
kubectl describe pod $POD_NAME | grep -A 5 "Events:"
```

**Expected Outcome**: 
- Pod restarts automatically
- Restart count increases
- Events show liveness probe failure and restart

**Use Case**: Automatic recovery from application deadlocks or crashes

### Test 5: Startup Probe - Initialization Time

Simulate a slow-starting application:

```bash
# Create a test deployment with artificial delay
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo-slow-start
spec:
  replicas: 1
  selector:
    matchLabels:
      app: podinfo-slow-start
  template:
    metadata:
      labels:
        app: podinfo-slow-start
    spec:
      containers:
      - name: podinfo
        image: ghcr.io/stefanprodan/podinfo:latest
        env:
        - name: PODINFO_DELAY
          value: "30"  # 30 second startup delay
        ports:
        - containerPort: 9898
        startupProbe:
          httpGet:
            path: /healthz
            port: 9898
          periodSeconds: 5
          failureThreshold: 12  # Allows 60 seconds
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 5
EOF

# Watch the pod start (startup probe gives it time)
kubectl get pods -l app=podinfo-slow-start -w

# Cleanup
kubectl delete deployment podinfo-slow-start
```

**Expected Outcome**: Pod successfully starts despite delay, startup probe prevents premature liveness checks

### Test 6: Probe Failure Under Load

Test probe behavior during high CPU usage:

```bash
# Get a pod name
POD_NAME=$(kubectl get pod -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Port forward for load testing
kubectl port-forward $POD_NAME 9898:9898 &
PF_PID=$!

# Generate load with delays (stress the timeout)
for i in {1..50}; do
  curl -s "http://localhost:9898/delay/2" &
done

# Monitor pod status
kubectl get pods -l app=podinfo -w

# Check probe timeout behavior
kubectl describe pod $POD_NAME | grep -A 5 "Warning"

# Wait for requests to complete
wait

# Cleanup
kill $PF_PID
```

**Expected Outcome**: Probes may fail temporarily but should recover; pod should remain healthy

### Test 7: Graceful Shutdown

Test graceful shutdown with readiness probe:

```bash
# Get a pod name
POD_NAME=$(kubectl get pod -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Start a long-running request in background
kubectl exec $POD_NAME -- sh -c 'wget -qO- http://localhost:9898/delay/20 &'

# Delete the pod (triggers SIGTERM)
kubectl delete pod $POD_NAME --grace-period=30

# Watch graceful termination
kubectl get pods -l app=podinfo -w
```

**Expected Outcome**: Pod stops accepting new traffic immediately (readiness fails), completes in-flight requests, then terminates

## Monitoring Probe Health

### Check Probe Events

```bash
# View probe-related events
kubectl get events --sort-by='.lastTimestamp' | grep -i "liveness\|readiness\|startup\|unhealthy"

# Watch events in real-time
kubectl get events -w
```

### Probe Metrics in Prometheus

If you have Prometheus configured (BP-03), these metrics are useful:

```promql
# Probe success rate
sum(rate(prober_probe_total{job="podinfo",result="successful"}[5m])) by (probe_type)

# Probe duration
histogram_quantile(0.99, sum(rate(prober_probe_duration_seconds_bucket[5m])) by (le, probe_type))
```

### Check Probe Configuration

```bash
# View current probe configuration
kubectl get deployment podinfo -o yaml | grep -A 15 "livenessProbe\|readinessProbe\|startupProbe"
```

## Troubleshooting Guide

### Pod Stuck in "Not Ready" State

**Symptoms**: Pod shows `0/1` ready for extended period

**Diagnosis**:
```bash
POD_NAME=<your-pod-name>
kubectl describe pod $POD_NAME | grep -A 10 "Readiness:"
kubectl logs $POD_NAME
kubectl exec $POD_NAME -- wget -O- -S http://localhost:9898/readyz
```

**Common Causes**:
- Application not listening on correct port
- Readiness endpoint returning non-200 status
- Network policy blocking kubelet access
- Probe timeout too short for application response time

### Pod Restart Loop

**Symptoms**: High restart count, pod constantly restarting

**Diagnosis**:
```bash
POD_NAME=<your-pod-name>
kubectl describe pod $POD_NAME | grep -A 10 "Liveness:"
kubectl logs $POD_NAME --previous
```

**Common Causes**:
- Liveness probe too aggressive (short failureThreshold)
- Application actually crashing (check previous logs)
- Resource constraints causing timeouts
- Incorrect probe endpoint configuration

### Startup Probe Failing

**Symptoms**: Pod never reaches running state

**Diagnosis**:
```bash
POD_NAME=<your-pod-name>
kubectl describe pod $POD_NAME | grep -A 10 "Startup:"
kubectl logs $POD_NAME
```

**Common Causes**:
- Application takes longer than failureThreshold * periodSeconds
- Startup endpoint not available
- Missing dependencies (DB, cache, etc.)

## Best Practices Learned

### Probe Selection Guidelines

1. **Startup Probe**: Use when app has variable initialization time
   - Prevents liveness probe from killing slow-starting apps
   - Set failureThreshold * periodSeconds > max startup time

2. **Liveness Probe**: Use to detect application deadlock/crash
   - Should check basic application health only
   - Avoid expensive operations (DB queries, external API calls)
   - Conservative settings to avoid false positives

3. **Readiness Probe**: Use to control traffic routing
   - Can check dependencies (DB connectivity, cache availability)
   - More sensitive than liveness (faster failure detection)
   - Use for gradual traffic draining

### Configuration Recommendations

```yaml
# Recommended probe timings
startupProbe:
  periodSeconds: 5
  failureThreshold: 12  # 60s total startup time
  
livenessProbe:
  periodSeconds: 10
  failureThreshold: 3   # 30s before restart
  
readinessProbe:
  periodSeconds: 5
  failureThreshold: 3   # 15s before removing from service
```

### Probe Endpoint Design

- `/healthz`: Lightweight check (return 200 if process alive)
- `/readyz`: Check readiness state and critical dependencies
- Both should complete in < 1 second
- Implement proper error handling and timeout protection

## Next Steps

After completing BP-02, you should:

1. **Move to BP-03**: Set up Prometheus to monitor probe metrics
2. **Implement monitoring**: Create alerts for probe failures
3. **Document runbooks**: Define response procedures for probe failures
4. **Test in production**: Validate probe settings under real load

## Reference

- [Kubernetes Probe Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Podinfo API Documentation](https://github.com/stefanprodan/podinfo)
- Probe endpoints:
  - `GET /healthz` - Liveness check
  - `GET /readyz` - Readiness check
  - `POST /readyz/enable` - Enable readiness
  - `POST /readyz/disable` - Disable readiness
