#!/bin/bash
# ============================================================
# MyBookStore - deploy-all.sh
# Despliega todos los stacks CloudFormation en orden correcto.
# Compatible con AWS Academy - usa LabRole exclusivamente.
#
# USO:
#   chmod +x deploy-all.sh
#   ./deploy-all.sh
#
# PREREQUISITOS:
#   - aws configure con credenciales Academy activas
#   - kubectl instalado localmente
#   - Docker corriendo
#   - Obtener LabRole ARN: aws iam get-role --role-name LabRole --query Role.Arn --output text
# ============================================================

set -e

# ── Configuracion - EDITA ESTOS VALORES ─────────────────────
PROJECT="bookstore"
REGION="us-east-1"
TEMPLATES_DIR="$(dirname "$0")"

# Obtener automaticamente el ARN del LabRole
LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query Role.Arn --output text 2>/dev/null)
if [ -z "$LAB_ROLE_ARN" ]; then
  echo "ERROR: No se pudo obtener el ARN de LabRole."
  echo "Verifica que tus credenciales Academy esten activas: aws sts get-caller-identity"
  exit 1
fi
# ─────────────────────────────────────────────────────────────

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="$AWS_ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
REPO_ROOT="$(dirname "$0")/.."

echo "============================================"
echo "  MyBookStore - Despliegue CloudFormation"
echo "  Account : $AWS_ACCOUNT"
echo "  Region  : $REGION"
echo "  Project : $PROJECT"
echo "  LabRole : $LAB_ROLE_ARN"
echo "============================================"
echo ""

# Funcion helper para desplegar un stack
deploy_stack() {
  local STACK_NAME=$1
  local TEMPLATE=$2
  shift 2
  local PARAMS=("$@")

  echo "──────────────────────────────────────────"
  echo "  Desplegando: $STACK_NAME"
  echo "──────────────────────────────────────────"

  aws cloudformation deploy \
    --template-file "$TEMPLATES_DIR/$TEMPLATE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides ProjectName="$PROJECT" "${PARAMS[@]}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION"

  echo "  OK $STACK_NAME completado"
  echo ""
}

# ── 01: VPC ──
deploy_stack "${PROJECT}-vpc" "01-vpc.yaml" \
  AZ1=us-east-1a \
  AZ2=us-east-1b

# ── 02: Security Groups ──
deploy_stack "${PROJECT}-security-groups" "02-security-groups.yaml"

# ── 03: ECR ──
deploy_stack "${PROJECT}-ecr" "03-ecr.yaml"

# ── Build y push de imagenes Docker a ECR ──
echo "──────────────────────────────────────────"
echo "  Build y push imagenes Docker a ECR"
echo "──────────────────────────────────────────"

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_BASE"

declare -A SERVICE_DIRS=(
  ["books-service"]="backend"
  ["auth-service"]="services/auth-service"
  ["reviews-service"]="services/reviews-service"
)

for SERVICE in books-service auth-service reviews-service; do
  SRC_DIR="${SERVICE_DIRS[$SERVICE]}"
  echo "  Building $SERVICE desde $REPO_ROOT/$SRC_DIR..."
  docker build -t "${PROJECT}-${SERVICE}" "$REPO_ROOT/$SRC_DIR"
  docker tag "${PROJECT}-${SERVICE}:latest" "$ECR_BASE/${PROJECT}-${SERVICE}:latest"
  docker push "$ECR_BASE/${PROJECT}-${SERVICE}:latest"
  echo "  OK $SERVICE subido"
done
echo ""

# ── 04: EKS (tarda 15-25 min) ──
echo "  AVISO: El stack EKS tarda entre 15 y 25 minutos en AWS Academy."
deploy_stack "${PROJECT}-eks" "04-eks.yaml" \
  LabRoleArn="$LAB_ROLE_ARN" \
  KubernetesVersion="1.31" \
  NodeInstanceType=t3.medium \
  NodeMinSize=2 \
  NodeMaxSize=4 \
  NodeDesiredSize=2

# Configurar kubectl localmente
echo "  Configurando kubectl..."
aws eks update-kubeconfig --name "${PROJECT}-cluster" --region "$REGION"
echo "  OK kubectl configurado"
echo ""

# ── 05: DynamoDB ──
deploy_stack "${PROJECT}-dynamodb" "05-dynamodb.yaml"

# ── 06: S3 ──
deploy_stack "${PROJECT}-s3" "06-s3.yaml"

# ── Build React y subir a S3 ──
echo "──────────────────────────────────────────"
echo "  Build React (VITE_API_URL placeholder)"
echo "──────────────────────────────────────────"
FRONTEND_BUCKET="${PROJECT}-frontend-${AWS_ACCOUNT}"
cd "$REPO_ROOT/frontend"
VITE_API_URL="https://PLACEHOLDER" npm run build
aws s3 sync dist/ "s3://$FRONTEND_BUCKET" --delete
cd -
echo "  OK Frontend subido a S3 (URL pendiente de CloudFront)"
echo ""

# ── Despliegue manifiestos K8s ──
echo "──────────────────────────────────────────"
echo "  Aplicando manifiestos Kubernetes"
echo "──────────────────────────────────────────"
K8S_DIR="$REPO_ROOT/k8s"

# Reemplazar account ID en deployments si es necesario
sed -i "s/<ACCOUNT_ID>/$AWS_ACCOUNT/g" \
  "$K8S_DIR/books-service/books-deployment.yaml" \
  "$K8S_DIR/auth-service/auth-deployment.yaml" \
  "$K8S_DIR/reviews-service/reviews-deployment.yaml" 2>/dev/null || true

kubectl apply -f "$K8S_DIR/books-service/"
kubectl apply -f "$K8S_DIR/auth-service/"
kubectl apply -f "$K8S_DIR/reviews-service/"
kubectl apply -f "$K8S_DIR/ingress.yaml"

echo "  Esperando pods listos (max 3 min)..."
kubectl wait --for=condition=available deployment/books-deployment   --timeout=180s || true
kubectl wait --for=condition=available deployment/auth-deployment    --timeout=180s || true
kubectl wait --for=condition=available deployment/reviews-deployment --timeout=180s || true
echo "  OK Pods desplegados"
echo ""

# Obtener DNS del ALB del Ingress
echo "  Obteniendo DNS del ALB (puede tardar 1-2 min)..."
sleep 60
ALB_DNS=$(kubectl get ingress bookstore-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
  echo "  ALB aun sin DNS asignado. Espera 2 minutos y ejecuta:"
  echo "  kubectl get ingress bookstore-ingress"
  echo "  Luego despliega manualmente el stack CloudFront:"
  echo "  aws cloudformation deploy --template-file $TEMPLATES_DIR/07-cloudfront.yaml \\"
  echo "    --stack-name ${PROJECT}-cloudfront \\"
  echo "    --parameter-overrides ProjectName=${PROJECT} AlbDnsName=<ALB_DNS>"
  echo ""
else
  echo "  ALB DNS: $ALB_DNS"

  # ── 07: CloudFront ──
  deploy_stack "${PROJECT}-cloudfront" "07-cloudfront.yaml" \
    AlbDnsName="$ALB_DNS"

  CF_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name "${PROJECT}-cloudfront" \
    --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDomain'].OutputValue" \
    --output text --region "$REGION")

  # Rebuild frontend con URL real de CloudFront
  echo "  Rebuild frontend con URL real: https://$CF_DOMAIN"
  cd "$REPO_ROOT/frontend"
  VITE_API_URL="https://$CF_DOMAIN" npm run build
  aws s3 sync dist/ "s3://$FRONTEND_BUCKET" --delete
  cd -

  # Invalidar cache CloudFront
  CF_ID=$(aws cloudformation describe-stacks \
    --stack-name "${PROJECT}-cloudfront" \
    --query "Stacks[0].Outputs[?OutputKey=='CloudFrontId'].OutputValue" \
    --output text --region "$REGION")
  aws cloudfront create-invalidation --distribution-id "$CF_ID" --paths "/*"
  echo "  OK Frontend actualizado con URL real"
  echo ""

  # ── 08: Lambda (depende de DynamoDB, S3 y CloudFront) ──
  deploy_stack "${PROJECT}-lambda" "08-lambda.yaml" \
    LabRoleArn="$LAB_ROLE_ARN" \
    StockThreshold=3
fi

echo "============================================"
echo "  DESPLIEGUE COMPLETO"
echo "============================================"
echo ""
kubectl get pods
echo ""
[ -n "$CF_DOMAIN" ] && echo "  URL de la aplicacion: https://$CF_DOMAIN"
echo ""
echo "  NOTA: Confirma kubectl get nodes y kubectl get pods"
echo "  antes de hacer pruebas funcionales."