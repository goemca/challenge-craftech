#!/usr/bin/env sh
set -eu

CLUSTER_NAME="devops-interview"

command -v docker >/dev/null || { echo "docker is required"; exit 1; }
command -v kind >/dev/null || { echo "kind is required"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }

kind get clusters | grep -qx "${CLUSTER_NAME}" || \
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml

docker build -t devops-backend:local backend
docker build -t devops-frontend:local frontend
kind load docker-image devops-backend:local --name "${CLUSTER_NAME}"
kind load docker-image devops-frontend:local --name "${CLUSTER_NAME}"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secret.example.yaml
kubectl apply -f kubernetes/database.yaml
kubectl rollout status deployment/database -n devops-app --timeout=180s
kubectl delete job backend-migrations -n devops-app --ignore-not-found
kubectl apply -f kubernetes/migration-job.yaml
kubectl wait --for=condition=Complete job/backend-migrations -n devops-app --timeout=180s
kubectl apply -f kubernetes/backend.yaml
kubectl apply -f kubernetes/frontend.yaml
kubectl apply -f kubernetes/ingress.yaml

kubectl rollout status deployment/backend -n devops-app --timeout=180s
kubectl rollout status deployment/frontend -n devops-app --timeout=180s

echo "Application available at http://localhost:8080"
echo "Test with: curl http://localhost:8080/healthz"
