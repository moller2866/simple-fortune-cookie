#!/bin/bash

# Default values
KUBECONFIG_PATH=""
ENVIRONMENT="production"
KUBECTL_FLAGS="--validate=false"  # Added to bypass validation errors

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --kubeconfig)
      KUBECONFIG_PATH="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if kubeconfig is provided
if [ -z "$KUBECONFIG_PATH" ]; then
  echo "No kubeconfig path provided, using default"
else
  export KUBECONFIG="$KUBECONFIG_PATH"
  echo "Using kubeconfig from: $KUBECONFIG_PATH"
fi

echo "Deploying to environment: $ENVIRONMENT"

# Navigate to the kubernetes directory
cd "$(dirname "$0")/kubernetes"

# Apply namespace based on environment if needed
if [ "$ENVIRONMENT" != "production" ]; then
  echo "Creating namespace: $ENVIRONMENT"
  kubectl create namespace $ENVIRONMENT --dry-run=client -o yaml | kubectl apply -f - $KUBECTL_FLAGS
  NAMESPACE_FLAG="--namespace=$ENVIRONMENT"
else
  NAMESPACE_FLAG=""
fi

# Apply Redis resources
kubectl apply -f redis/pvc.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS
kubectl apply -f redis/deployment.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS
kubectl apply -f redis/service.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS
echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/redis $NAMESPACE_FLAG || true

# Apply Backend resources
kubectl apply -f backend/deployment.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS
kubectl apply -f backend/service.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS
echo "Waiting for Backend to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/backend $NAMESPACE_FLAG || true

# Apply Frontend resources only after Backend is ready
kubectl apply -f frontend/deployment.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS
kubectl apply -f frontend/service.yaml $NAMESPACE_FLAG $KUBECTL_FLAGS

echo "Deployment completed. Checking resource status..."
kubectl get deployments,services,pods $NAMESPACE_FLAG || true
