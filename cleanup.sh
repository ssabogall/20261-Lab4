#!/bin/bash
# ============================================================
# Script de limpieza - Eliminar TODOS los recursos de AWS
# Ejecutar cuando quieras dejar de pagar
#
# USO:
#   chmod +x cleanup.sh
#   ./cleanup.sh
# ============================================================

set -e

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
CLUSTER_NAME="bookstore-cluster"

echo "============================================"
echo "  ⚠ ELIMINANDO TODOS LOS RECURSOS"
echo "  Account: $AWS_ACCOUNT_ID"
echo "  Cluster: $CLUSTER_NAME"
echo "============================================"
echo ""
read -p "¿Estás seguro? (escribe 'si' para confirmar): " confirm
if [ "$confirm" != "si" ]; then
  echo "Cancelado."
  exit 0
fi
echo ""

# 1. Eliminar servicios de Kubernetes (borra el Load Balancer)
echo "[1/5] Eliminando servicios de Kubernetes..."
kubectl delete -f k8s/frontend-deployment.yaml 2>/dev/null || true
kubectl delete -f k8s/backend-deployment.yaml 2>/dev/null || true
echo "      Esperando 30s a que AWS elimine el Load Balancer..."
sleep 30
echo ""

# 2. Eliminar el Service Account
echo "[2/5] Eliminando Service Account..."
eksctl delete iamserviceaccount \
  --name bookstore-backend-sa \
  --namespace default \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION 2>/dev/null || true
echo ""

# 3. Eliminar el clúster
echo "[3/5] Eliminando clúster EKS (tarda ~10 min)..."
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION
echo ""

# 4. Eliminar repositorios ECR
echo "[4/5] Eliminando repositorios ECR..."
aws ecr delete-repository --repository-name bookstore/backend --region $AWS_REGION --force 2>/dev/null || true
aws ecr delete-repository --repository-name bookstore/frontend --region $AWS_REGION --force 2>/dev/null || true
echo ""

# 5. Eliminar la política IAM
echo "[5/5] Eliminando política IAM..."
aws iam delete-policy \
  --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/BookstoreDynamoDBPolicy 2>/dev/null || true
echo ""

echo "============================================"
echo "  ✓ LIMPIEZA COMPLETA"
echo "  Nota: La tabla DynamoDB NO se eliminó."
echo "  Si quieres eliminarla también:"
echo "    aws dynamodb delete-table --table-name tb_books --region us-east-1"
echo "============================================"
