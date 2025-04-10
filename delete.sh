#!/bin/bash

# Navigate to the kubernetes directory
cd "$(dirname "$0")/kubernetes"

echo "Deleting all deployed resources..."

# Delete Frontend resources
kubectl delete -f frontend/service.yaml
kubectl delete -f frontend/deployment.yaml

# Delete Backend resources
kubectl delete -f backend/service.yaml
kubectl delete -f backend/deployment.yaml

# Delete Redis resources
kubectl delete -f redis/service.yaml
kubectl delete -f redis/deployment.yaml
kubectl delete -f redis/pvc.yaml

echo "Deletion completed. Verifying resources are gone..."
kubectl get deployments,services,pods
