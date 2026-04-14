#!/bin/bash
# ============================================================
# Script de despliegue completo - Bookstore en EKS
# Ejecutar desde la carpeta k8s/
#
# USO:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# PREREQUISITOS:
#   - AWS CLI configurado (aws configure)
#   - Docker corriendo (sudo service docker start)
#   - eksctl, kubectl y helm instalados
#   - Estar en la carpeta raíz del proyecto (donde están las carpetas backend/ y frontend/)
# ============================================================

set -e  # Detener si algo falla

# ── Variables ──
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
CLUSTER_NAME="bookstore-cluster"
ECR_BASE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "============================================"
echo "  Account ID: $AWS_ACCOUNT_ID"
echo "  Region:     $AWS_REGION"
echo "  Cluster:    $CLUSTER_NAME"
echo "  ECR:        $ECR_BASE"
echo "============================================"
echo ""

# ── Paso 1: Reemplazar TU_ACCOUNT_ID en los manifiestos ──
echo "[1/7] Reemplazando Account ID en los manifiestos..."
sed -i "s/TU_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" k8s/backend-deployment.yaml
sed -i "s/TU_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" k8s/frontend-deployment.yaml
echo "      ✓ Manifiestos actualizados"
echo ""

# ── Paso 2: Login en ECR ──
echo "[2/7] Autenticando en ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_BASE
echo ""

# ── Paso 3: Build y push de imágenes ──
echo "[3/7] Construyendo y subiendo imagen del BACKEND..."
docker build -t bookstore/backend ./backend
docker tag bookstore/backend:latest $ECR_BASE/bookstore/backend:latest
docker push $ECR_BASE/bookstore/backend:latest
echo "      ✓ Backend subido"
echo ""

echo "[4/7] Construyendo y subiendo imagen del FRONTEND..."
docker build \
  --build-arg VITE_API_URL=http://backend-service:5001 \
  -t bookstore/frontend ./frontend
docker tag bookstore/frontend:latest $ECR_BASE/bookstore/frontend:latest
docker push $ECR_BASE/bookstore/frontend:latest
echo "      ✓ Frontend subido"
echo ""

# ── Paso 4: Crear el clúster ──
echo "[5/7] Creando clúster EKS (esto tarda 15-25 min)..."
eksctl create cluster -f k8s/cluster-config.yaml
echo "      ✓ Clúster creado"
echo ""

# ── Paso 5: Crear IAM policy y Service Account ──
echo "[6/7] Configurando permisos de DynamoDB (IRSA)..."
aws iam create-policy \
  --policy-name BookstoreDynamoDBPolicy \
  --policy-document file://k8s/dynamodb-policy.json \
  2>/dev/null || echo "      (La política ya existe, continuando...)"

eksctl create iamserviceaccount \
  --name bookstore-backend-sa \
  --namespace default \
  --cluster $CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/BookstoreDynamoDBPolicy \
  --approve \
  --region $AWS_REGION
echo "      ✓ Permisos configurados"
echo ""

# ── Paso 6: Desplegar ──
echo "[7/7] Desplegando en Kubernetes..."
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
echo ""

# ── Esperar a que los pods estén listos ──
echo "Esperando a que los pods estén listos..."
kubectl wait --for=condition=available deployment/backend --timeout=120s
kubectl wait --for=condition=available deployment/frontend --timeout=120s
echo ""

# ── Mostrar resultado ──
echo "============================================"
echo "  ✓ ¡DESPLIEGUE COMPLETO!"
echo "============================================"
echo ""
kubectl get pods
echo ""
echo "URL pública (espera 1-2 min si dice <pending>):"
kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
echo ""
echo "Si la URL aún no aparece, ejecuta:"
echo "  kubectl get service frontend-service"
