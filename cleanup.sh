#!/bin/bash
# ============================================================
# Script de limpieza - Eliminar TODOS los recursos de AWS
# Ejecutar cuando quieras terminar el laboratorio
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
echo "  ⚠  ELIMINANDO TODOS LOS RECURSOS"
echo "  Account: $AWS_ACCOUNT_ID"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region:  $AWS_REGION"
echo "============================================"
echo ""
read -p "¿Estás seguro? (escribe 'si' para confirmar): " confirm
if [ "$confirm" != "si" ]; then
  echo "Cancelado."
  exit 0
fi
echo ""

# 1. Eliminar manifiestos de Kubernetes (borra el Load Balancer primero)
echo "[1/4] Eliminando recursos de Kubernetes..."
kubectl delete -f k8s/frontend/frontend-service.yaml 2>/dev/null || true
kubectl delete -f k8s/ingress.yaml 2>/dev/null || true
echo "      Esperando 30s a que AWS elimine el Load Balancer..."
sleep 30
kubectl delete -f k8s/frontend/ 2>/dev/null || true
kubectl delete -f k8s/books-service/ 2>/dev/null || true
kubectl delete -f k8s/auth-service/ 2>/dev/null || true
kubectl delete -f k8s/reviews-service/ 2>/dev/null || true
kubectl delete -f k8s/mongodb/ 2>/dev/null || true
echo "      ✓ Recursos eliminados"
echo ""

# 2. Eliminar el clúster EKS
echo "[2/4] Eliminando clúster EKS (tarda ~10 min)..."
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION
echo "      ✓ Clúster eliminado"
echo ""

# 3. Eliminar repositorios ECR
echo "[3/4] Eliminando repositorios ECR..."
for repo in bookstore-books-service bookstore-auth-service bookstore-reviews-service bookstore-frontend; do
  aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force 2>/dev/null || true
  echo "      ✓ $repo eliminado"
done
echo ""

# 4. Limpiar imágenes Docker locales
echo "[4/4] Limpiando imágenes Docker locales..."
docker rmi bookstore-books-service:latest 2>/dev/null || true
docker rmi bookstore-auth-service:latest 2>/dev/null || true
docker rmi bookstore-reviews-service:latest 2>/dev/null || true
docker rmi bookstore-frontend:latest 2>/dev/null || true
echo "      ✓ Imágenes locales eliminadas"
echo ""

echo "============================================"
echo "  ✓ LIMPIEZA COMPLETA"
echo "  Todos los recursos de AWS fueron eliminados"
echo "  y ya no generarán costos."
echo "============================================"
