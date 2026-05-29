#!/bin/bash
# renew-credentials.sh
# Ejecutar cada vez que reinicies el laboratorio Academy

set -e

echo "Reconectando kubectl..."
aws eks update-kubeconfig --name bookstore-cluster --region us-east-1

echo "Actualizando secret aws-credentials en Kubernetes..."
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key) \
  --from-literal=AWS_SESSION_TOKEN=$(aws configure get aws_session_token) \
  --from-literal=AWS_REGION=us-east-1 \
  --from-literal=DYNAMO_TABLE=bookstore-books \
  --from-literal=NODE_ENV=production \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Reiniciando pods..."
kubectl rollout restart deployment/books-deployment
kubectl rollout restart deployment/auth-deployment
kubectl rollout restart deployment/reviews-deployment

echo "Esperando pods listos..."
kubectl rollout status deployment/books-deployment   --timeout=120s
kubectl rollout status deployment/auth-deployment    --timeout=120s
kubectl rollout status deployment/reviews-deployment --timeout=120s

echo ""
echo "Listo. Estado actual:"
kubectl get pods