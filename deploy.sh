set -e

NAME="kubernetes-demo-api"
USER="bsen20"
IMAGE="$USER/$NAME:latest"

echo "Building Docker image..."
docker build -t $IMAGE .

echo "Pushing Docker image to Docker Hub..."
docker push $IMAGE

echo "Applying Kubernetes configuration..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
echo "Deployment and Service created successfully!"

echo "Gettings pods..."
kubectl get pods

echo "Getting services..."
kubectl get services

echo "Fetching the main service"
kubectl get service $NAME-service

