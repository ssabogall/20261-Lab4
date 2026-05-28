#!/bin/bash
# ============================================================
# MyBookStore — deploy-all.sh
# Despliega todos los stacks de CloudFormation en orden.
#
# USO:
#   chmod +x deploy-all.sh
#   ./deploy-all.sh
#
# PREREQUISITOS:
#   - aws configure completado
#   - Key Pair creado en EC2 con el nombre configurado abajo
#   - Docker corriendo (para el paso de build de imágenes)
#   - kubectl instalado
# ============================================================

set -e

# ── Configuración — edita estos valores ──────────────────────
PROJECT="bookstore"
REGION="us-east-1"
KEY_PAIR_NAME="bookstore-key"          # Nombre del Key Pair en EC2
BASTION_CIDR="0.0.0.0/0"             # Reemplaza con tu IP: X.X.X.X/32
TEMPLATES_DIR="$(dirname "$0")/templates"
# ─────────────────────────────────────────────────────────────

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="$AWS_ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

echo "============================================"
echo "  MyBookStore — Despliegue CloudFormation"
echo "  Account: $AWS_ACCOUNT"
echo "  Region:  $REGION"
echo "  Project: $PROJECT"
echo "============================================"
echo ""

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

  echo "  ✓ $STACK_NAME — CREATE_COMPLETE"
  echo ""
}

# ── Stack 01: VPC ──
deploy_stack "${PROJECT}-vpc" "01-vpc.yaml" \
  AZ1=us-east-1a \
  AZ2=us-east-1b

# ── Stack 02: Security Groups ──
deploy_stack "${PROJECT}-security-groups" "02-security-groups.yaml" \
  BastionAllowedCidr="$BASTION_CIDR"

# ── Stack 03: Bastion Host ──
deploy_stack "${PROJECT}-bastion" "03-bastion.yaml" \
  KeyPairName="$KEY_PAIR_NAME"

# ── Stack 04: ECR ──
deploy_stack "${PROJECT}-ecr" "04-ecr.yaml"

# ── Build y push de imágenes Docker ──
echo "──────────────────────────────────────────"
echo "  Build y push de imágenes a ECR"
echo "──────────────────────────────────────────"
REPO_ROOT="$(dirname "$0")/.."

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_BASE"

for SERVICE in books-service auth-service reviews-service; do
  SRC_DIR="backend"
  [ "$SERVICE" = "auth-service" ]     && SRC_DIR="services/auth-service"
  [ "$SERVICE" = "reviews-service" ]  && SRC_DIR="services/reviews-service"

  docker build -t "${PROJECT}-${SERVICE}" "$REPO_ROOT/$SRC_DIR"
  docker tag "${PROJECT}-${SERVICE}:latest" "$ECR_BASE/${PROJECT}-${SERVICE}:latest"
  docker push "$ECR_BASE/${PROJECT}-${SERVICE}:latest"
  echo "  ✓ $SERVICE subido a ECR"
done
echo ""

# ── Stack 05: EKS (tarda ~20 min) ──
echo "  AVISO: El stack EKS tarda entre 15 y 25 minutos."
deploy_stack "${PROJECT}-eks" "05-eks.yaml" \
  NodeInstanceType=t3.medium \
  NodeMinSize=2 \
  NodeMaxSize=4 \
  NodeDesiredSize=2

# Configurar kubectl
echo "  Configurando kubectl..."
aws eks update-kubeconfig --name "${PROJECT}-cluster" --region "$REGION"
echo "  ✓ kubectl configurado"
echo ""

# ── Stack 06: DynamoDB ──
deploy_stack "${PROJECT}-dynamodb" "06-dynamodb.yaml"

# ── Stack 07: S3 ──
deploy_stack "${PROJECT}-s3" "07-s3.yaml"

# ── Build y deploy del frontend a S3 ──
echo "──────────────────────────────────────────"
echo "  Build React y sync a S3"
echo "──────────────────────────────────────────"
FRONTEND_BUCKET="${PROJECT}-frontend-${AWS_ACCOUNT}"

# El ALB se crea después del deploy K8s; por ahora usamos placeholder
# que deberás actualizar con: VITE_API_URL=https://<cloudfront-domain>
cd "$REPO_ROOT/frontend"
VITE_API_URL="https://PLACEHOLDER" npm run build
aws s3 sync dist/ "s3://$FRONTEND_BUCKET" --delete
cd -
echo "  ✓ Frontend subido a S3"
echo ""

# ── Despliegue de manifiestos K8s ──
echo "──────────────────────────────────────────"
echo "  Aplicando manifiestos Kubernetes"
echo "──────────────────────────────────────────"
K8S_DIR="$REPO_ROOT/k8s"

# Actualizar Account ID en deployments
sed -i "s/261273955683/$AWS_ACCOUNT/g" \
  "$K8S_DIR/books-service/books-deployment.yaml" \
  "$K8S_DIR/auth-service/auth-deployment.yaml" \
  "$K8S_DIR/reviews-service/reviews-deployment.yaml"

# Actualizar nombre de tabla DynamoDB en el secret
DYNAMO_TABLE_B64=$(echo -n "${PROJECT}-books" | base64)
sed -i "s|dynamo-table:.*|dynamo-table: $DYNAMO_TABLE_B64|" \
  "$K8S_DIR/books-service/dynamo-secret.yaml"

kubectl apply -f "$K8S_DIR/books-service/"
kubectl apply -f "$K8S_DIR/auth-service/"
kubectl apply -f "$K8S_DIR/reviews-service/"
kubectl apply -f "$K8S_DIR/ingress.yaml"

echo "  Esperando pods listos..."
kubectl wait --for=condition=available deployment/books-deployment   --timeout=180s
kubectl wait --for=condition=available deployment/auth-deployment    --timeout=180s
kubectl wait --for=condition=available deployment/reviews-deployment --timeout=180s
echo "  ✓ Pods corriendo"
echo ""

# Obtener DNS del ALB (creado por el Ingress)
echo "  Obteniendo DNS del ALB..."
sleep 30
ALB_DNS=$(kubectl get svc -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
  kubectl get ingress bookstore-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
  echo "PENDING")
echo "  ALB DNS: $ALB_DNS"
echo ""

# ── Stack 08: CloudFront ──
if [ "$ALB_DNS" != "PENDING" ]; then
  deploy_stack "${PROJECT}-cloudfront" "08-cloudfront.yaml" \
    AlbDnsName="$ALB_DNS"

  # Actualizar VITE_API_URL con el dominio real de CloudFront
  CF_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name "${PROJECT}-cloudfront" \
    --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDomain'].OutputValue" \
    --output text --region "$REGION")

  echo "  Actualizando frontend con CloudFront domain..."
  cd "$REPO_ROOT/frontend"
  VITE_API_URL="https://$CF_DOMAIN" npm run build
  aws s3 sync dist/ "s3://$FRONTEND_BUCKET" --delete
  aws cloudfront create-invalidation \
    --distribution-id "$(aws cloudformation describe-stacks \
      --stack-name "${PROJECT}-cloudfront" \
      --query "Stacks[0].Outputs[?OutputKey=='CloudFrontId'].OutputValue" \
      --output text --region "$REGION")" \
    --paths "/*"
  cd -
  echo "  ✓ Frontend actualizado con URL real"
else
  echo "  ⚠ ALB aún no tiene DNS. Ejecuta el stack 08 manualmente:"
  echo "    aws cloudformation deploy --template-file templates/08-cloudfront.yaml \\"
  echo "      --stack-name ${PROJECT}-cloudfront \\"
  echo "      --parameter-overrides ProjectName=${PROJECT} AlbDnsName=<ALB_DNS>"
fi

# ── Stack 09: Lambdas ──
deploy_stack "${PROJECT}-lambda" "09-lambda.yaml" \
  StockThreshold=3

echo "============================================"
echo "  ✓ DESPLIEGUE COMPLETO"
echo "============================================"
echo ""
kubectl get pods
echo ""
if [ -n "$CF_DOMAIN" ]; then
  echo "  URL de la aplicación: https://$CF_DOMAIN"
fi
echo ""
echo "  IMPORTANTE: Confirma la suscripción SNS"
echo "  en el email: $STOCK_ALERT_EMAIL"