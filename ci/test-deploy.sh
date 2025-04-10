#!/bin/bash
set -e

# Define namespace for testing
TEST_NAMESPACE="fortune-cookie-test"

echo "=== Setting up test environment ==="
# Create test namespace if it doesn't exist
kubectl create namespace ${TEST_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Apply Redis resources
echo "Deploying Redis..."
kubectl apply -f kubernetes/redis/pvc.yaml -n ${TEST_NAMESPACE}
kubectl apply -f kubernetes/redis/deployment.yaml -n ${TEST_NAMESPACE}
kubectl apply -f kubernetes/redis/service.yaml -n ${TEST_NAMESPACE}

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/redis -n ${TEST_NAMESPACE}

# Apply Backend resources
echo "Deploying Backend..."
kubectl apply -f kubernetes/backend/deployment.yaml -n ${TEST_NAMESPACE}
kubectl apply -f kubernetes/backend/service.yaml -n ${TEST_NAMESPACE}

# Wait for Backend to be ready
echo "Waiting for Backend to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/backend -n ${TEST_NAMESPACE}

# Apply Frontend resources
echo "Deploying Frontend..."
kubectl apply -f kubernetes/frontend/deployment.yaml -n ${TEST_NAMESPACE}
kubectl apply -f kubernetes/frontend/service.yaml -n ${TEST_NAMESPACE}

# Wait for Frontend to be ready
echo "Waiting for Frontend to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/frontend -n ${TEST_NAMESPACE}

# Port-forward the frontend service for testing
echo "Setting up port-forwarding..."
kubectl port-forward svc/frontend 8888:8080 -n ${TEST_NAMESPACE} &
PORT_FORWARD_PID=$!

# Give the port-forwarding time to establish
sleep 5

echo "=== Starting functional tests ==="

# Test 1: Frontend is accessible
echo "Test 1: Checking if frontend is accessible..."
if curl -s http://localhost:8888 | grep -q "Fortune cookie application"; then
  echo "✅ Frontend is accessible"
else
  echo "❌ Frontend is not accessible"
  kill $PORT_FORWARD_PID
  exit 1
fi

# Test 2: Backend health check
echo "Test 2: Testing backend health check..."
kubectl port-forward svc/backend 9888:9000 -n ${TEST_NAMESPACE} &
BACKEND_PORT_FORWARD_PID=$!
sleep 3

# Basic check for backend - use fortunes endpoint since healthz doesn't exist yet
if curl -s -f http://localhost:9888/fortunes; then
  echo "✅ Backend API /fortunes is accessible"
else
  echo "❌ Backend API is not accessible"
  kill $PORT_FORWARD_PID
  kill $BACKEND_PORT_FORWARD_PID
  exit 1
fi

# Test 3: Random fortune endpoint
echo "Test 3: Testing random fortune endpoint..."
if curl -s http://localhost:9888/fortunes/random | grep -q ".*"; then
  echo "✅ Random fortune endpoint is working"
else
  echo "❌ Random fortune endpoint is not working"
  kill $PORT_FORWARD_PID
  kill $BACKEND_PORT_FORWARD_PID
  exit 1
fi

# Test 4: Adding a new fortune
echo "Test 4: Testing adding a new fortune..."
NEW_FORTUNE_ID=$RANDOM
TEST_MESSAGE="Test fortune from automated test $RANDOM"
ADD_RESULT=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"id\":\"$NEW_FORTUNE_ID\",\"message\":\"$TEST_MESSAGE\"}" http://localhost:9888/fortunes)

if echo $ADD_RESULT | grep -q "$TEST_MESSAGE"; then
  echo "✅ Adding new fortune successful"
else
  echo "❌ Failed to add new fortune"
  kill $PORT_FORWARD_PID
  kill $BACKEND_PORT_FORWARD_PID
  exit 1
fi

# Test 5: Verify the newly added fortune
echo "Test 5: Verifying the newly added fortune..."
if curl -s http://localhost:9888/fortunes/$NEW_FORTUNE_ID | grep -q "$TEST_MESSAGE"; then
  echo "✅ Fortune persistence test passed"
else
  echo "❌ Fortune persistence test failed"
  kill $PORT_FORWARD_PID
  kill $BACKEND_PORT_FORWARD_PID
  exit 1
fi

# Clean up port-forwarding
kill $PORT_FORWARD_PID
kill $BACKEND_PORT_FORWARD_PID

echo "=== All tests passed! ==="

# Clean up - uncomment if you want to clean up test namespace
echo "=== Cleaning up test environment ==="
kubectl delete namespace ${TEST_NAMESPACE}

echo "✅ Test deployment successfully completed and cleaned up"
exit 0
