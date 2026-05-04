#!/bin/bash
# ============================================================
# Script de despliegue completo - MyBookStore en EKS
#
# USO:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# PREREQUISITOS:
#   - AWS CLI configurado (aws configure)
#   - Docker corriendo
#   - eksctl, kubectl instalados
#   - Estar en la carpeta raíz del proyecto
# ============================================================

set -e

# ── Variables ──
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
CLUSTER_NAME="bookstore-cluster"
ECR_BASE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "============================================"
echo "  MyBookStore - Despliegue en EKS"
echo "  Account ID: $AWS_ACCOUNT_ID"
echo "  Region:     $AWS_REGION"
echo "  Cluster:    $CLUSTER_NAME"
echo "  ECR:        $ECR_BASE"
echo "============================================"
echo ""

# ── Paso 1: Login en ECR ──
echo "[1/6] Autenticando en ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_BASE
echo "      ✓ Autenticado"
echo ""

# ── Paso 2: Crear repositorios ECR si no existen ──
echo "[2/6] Creando repositorios ECR..."
for repo in bookstore-books-service bookstore-auth-service bookstore-reviews-service bookstore-frontend; do
  aws ecr describe-repositories --repository-names $repo --region $AWS_REGION 2>/dev/null || \
  aws ecr create-repository --repository-name $repo --region $AWS_REGION
  echo "      ✓ $repo"
done
echo ""

# ── Paso 3: Build y push de imágenes ──
echo "[3/6] Construyendo y subiendo imágenes..."

docker build -t bookstore-books-service ./backend
docker tag bookstore-books-service:latest $ECR_BASE/bookstore-books-service:latest
docker push $ECR_BASE/bookstore-books-service:latest
echo "      ✓ books-service subido"

docker build -t bookstore-auth-service ./services/auth-service
docker tag bookstore-auth-service:latest $ECR_BASE/bookstore-auth-service:latest
docker push $ECR_BASE/bookstore-auth-service:latest
echo "      ✓ auth-service subido"

docker build -t bookstore-reviews-service ./services/reviews-service
docker tag bookstore-reviews-service:latest $ECR_BASE/bookstore-reviews-service:latest
docker push $ECR_BASE/bookstore-reviews-service:latest
echo "      ✓ reviews-service subido"

docker build -t bookstore-frontend ./frontend
docker tag bookstore-frontend:latest $ECR_BASE/bookstore-frontend:latest
docker push $ECR_BASE/bookstore-frontend:latest
echo "      ✓ frontend subido"
echo ""

# ── Paso 4: Actualizar Account ID en los manifiestos ──
echo "[4/6] Actualizando Account ID en manifiestos..."
sed -i "s/261273955683/$AWS_ACCOUNT_ID/g" k8s/books-service/books-deployment.yaml
sed -i "s/261273955683/$AWS_ACCOUNT_ID/g" k8s/auth-service/auth-deployment.yaml
sed -i "s/261273955683/$AWS_ACCOUNT_ID/g" k8s/reviews-service/reviews-deployment.yaml
sed -i "s/261273955683/$AWS_ACCOUNT_ID/g" k8s/frontend/frontend-deployment.yaml
echo "      ✓ Manifiestos actualizados"
echo ""

# ── Paso 5: Crear el clúster EKS ──
echo "[5/6] Creando clúster EKS (esto tarda 15-25 min)..."
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodegroup-name standard-workers \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
echo "      ✓ Clúster creado"
echo ""

# ── Paso 6: Desplegar todos los manifiestos ──
echo "[6/6] Desplegando en Kubernetes..."

echo "      → MongoDB..."
kubectl apply -f k8s/mongodb/mongodb-secret.yaml
kubectl apply -f k8s/mongodb/mongodb-statefulset.yaml
kubectl apply -f k8s/mongodb/mongodb-service.yaml

echo "      → Esperando a que MongoDB esté listo..."
kubectl wait --for=condition=ready pod/mongodb-0 --timeout=120s

echo "      → Microservicios..."
kubectl apply -f k8s/books-service/
kubectl apply -f k8s/auth-service/
kubectl apply -f k8s/reviews-service/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/ingress.yaml

echo "      → Esperando a que los pods estén listos..."
kubectl wait --for=condition=available deployment/books-deployment --timeout=120s
kubectl wait --for=condition=available deployment/auth-deployment --timeout=120s
kubectl wait --for=condition=available deployment/reviews-deployment --timeout=120s
kubectl wait --for=condition=available deployment/frontend-deployment --timeout=120s
echo ""

# ── Poblar MongoDB con datos de prueba ──
echo "Poblando MongoDB con datos de prueba..."
BOOKS_POD=$(kubectl get pod -l app=books-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec $BOOKS_POD -- npm run seeder
echo "      ✓ Datos insertados"
echo ""

# ── Mostrar resultado ──
echo "============================================"
echo "  ✓ DESPLIEGUE COMPLETO"
echo "============================================"
echo ""
kubectl get pods
echo ""
echo "URL pública (espera 1-2 min si dice <pending>):"
kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
