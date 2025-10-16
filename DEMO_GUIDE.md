# GPU Cold Start vs Warm Start

## Architecture

- **FastAPI** app with GPU-based sentiment analysis (DistilBERT)
- **KEDA HTTP Add-on** for HTTP-based autoscaling (0-1 replicas)
- **Kubernetes** with NVIDIA GPU support

### Cold Start (First Request)
- Pod scheduled from 0 replicas
- Container startup
- GPU initialization
- Model loaded into GPU memory
- First inference
- **Total time: 20-60 seconds** (varies by GPU/model)

### Warm Start (Subsequent Requests)
- Pod already running
- Model already in GPU memory
- Just inference time
- **Total time: 50-200ms**

## Setup

1. **Rebuild with timing metrics:**
```bash
cd /home/user/AtlantaDemo
docker build -t gpu-demo:latest .
```

2. **Deploy:**
```bash
kubectl apply -f depc.yml
kubectl apply -f scaler.yml
```

3. **Port forward KEDA interceptor:**
```bash
kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080
```

## Run Demo

### Option 1: Automated Demo Script
```bash
./demo.sh
```

### Option 2: Manual Demo

**Step 1: Reset to 0 replicas**
```bash
kubectl scale deployment gpu-coldstart --replicas=0
kubectl get pods -l app=gpu-coldstart
```

**Step 2: Cold Start Test**
```bash
time curl -H "Host: gpu-coldstart.default.svc.cluster.local" \
  "http://localhost:8080/predict?text=This%20is%20amazing"
```

**Step 3: Warm Start Test** (immediately after)
```bash
time curl -H "Host: gpu-coldstart.default.svc.cluster.local" \
  "http://localhost:8080/predict?text=This%20is%20terrible"
```

## Response Format

```json
{
  "text": "This is amazing",
  "sentiment": "POSITIVE",
  "label": 1,
  "inference_time_ms": "45.23",
  "model_startup_time": "23.45s"
}
```

## Key Points for Demo

1. **KEDA HTTP Add-on queues requests** during cold start
2. **Readiness probe** ensures traffic only flows when model is ready
3. **GPU cold start is expensive** (20-60s) - warm requests are fast (50-200ms)
4. **Scale-to-zero** saves GPU costs when idle
5. **configurable scaledown period** (300s default) keeps pod warm between requests

## Monitoring

Watch pod lifecycle:
```bash
kubectl get pods -l app=gpu-coldstart -w
```

Check HTTPScaledObject status:
```bash
kubectl get httpscaledobject
```

View pod logs:
```bash
kubectl logs -l app=gpu-coldstart -f
```

