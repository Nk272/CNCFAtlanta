#!/bin/bash

set -e

echo "Building Docker image..."
cd /home/user/AtlantaDemo
docker build -t gpu-demo:latest .

echo ""
echo "Importing image to k3s..."
docker save gpu-demo:latest | sudo k3s ctr images import -

echo ""
echo "Restarting deployment..."
kubectl delete deployment gpu-coldstart 2>/dev/null || true
kubectl apply -f depc.yml

echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/gpu-coldstart || true

echo ""
echo "Deployment status:"
kubectl get deployment gpu-coldstart
kubectl get pods -l app=gpu-coldstart

echo ""
echo "✅ Rebuild complete!"

