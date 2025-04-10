#!/bin/bash

# Navigate to the kubernetes directory
cd "$(dirname "$0")/kubernetes"

# Apply Redis resources
kubectl apply -f redis/pvc.yaml
kubectl apply -f redis/deployment.yaml
kubectl apply -f redis/service.yaml
echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/redis

# Apply Backend resources
kubectl apply -f backend/deployment.yaml
kubectl apply -f backend/service.yaml
echo "Waiting for Backend to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/backend

# Apply Frontend resources only after Backend is ready
kubectl apply -f frontend/deployment.yaml
kubectl apply -f frontend/service.yaml

echo "Deployment completed. Checking resource status..."
kubectl get deployments,services,pods
