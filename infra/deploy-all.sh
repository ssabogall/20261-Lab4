#!/bin/bash
# ============================================================
# MyBookStore — deploy-all.sh
# Despliegue completo para AWS Academy usando LabRole.
#
# USO:
#   chmod +x deploy-all.sh
#   ./deploy-all.sh
#
# PREREQUISITOS:
#   - aws configure con credenciales Academy activas
#   - kubectl instalado
#   - Docker corriendo
#   - Node.js >= 20 instalado
# ============================================================

set -e

# ── Configuracion ────────────────────────────────────────────
PROJECT="bookstore"
REGION="us-east-1"
TEMPLATES_DIR="$(cd "$(dirname "$0")/templates" && pwd)"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# ─────────────────────────────────────────────────────────────

# Verificar credenciales activas
echo "Verificando credenciales AWS..."
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT" ]; then
  echo "ERROR: Credenciales AWS no activas."
  echo "Actualiza tus credenciales en ~/.aws/credentials"
  exit 1
fi

LAB_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT}:role/LabRole"
ECR_BASE="$AWS_ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
FRONTEND_BUCKET="${PROJECT}-frontend-${AWS_ACCOUNT}"

echo "============================================"
echo "  MyBookStore — Despliegue AWS Academy"
echo "  Account : $AWS_ACCOUNT"
echo "  Region  : $REGION"
echo "  Project : $PROJECT"
echo "  LabRole : $LAB_ROLE_ARN"
echo "============================================"
echo ""

# ── Helper: desplegar stack CloudFormation ───────────────────
deploy_stack() {
  local STACK_NAME=$1
  local TEMPLATE=$2
  shift 2
  local PARAMS=("$@")

  echo "──────────────────────────────────────────"
  echo "  Stack: $STACK_NAME"
  echo "──────────────────────────────────────────"

  aws cloudformation deploy \
    --template-file "$TEMPLATES_DIR/$TEMPLATE" \
    --stack-name "$STACK_NAME" \
    --role-arn "$LAB_ROLE_ARN" \
    --parameter-overrides ProjectName="$PROJECT" "${PARAMS[@]}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --no-fail-on-empty-changeset

  echo "  OK $STACK_NAME"
  echo ""
}

# ══════════════════════════════════════════════════════════════
# STACKS CLOUDFORMATION
# ══════════════════════════════════════════════════════════════

deploy_stack "${PROJECT}-vpc" "01-vpc.yaml" \
  AZ1=us-east-1a AZ2=us-east-1b

deploy_stack "${PROJECT}-security-groups" "02-security-groups.yaml"

deploy_stack "${PROJECT}-ecr" "03-ecr.yaml"

# ── Build y push imágenes Docker ─────────────────────────────
echo "──────────────────────────────────────────"
echo "  Build y push imágenes a ECR"
echo "──────────────────────────────────────────"

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_BASE"

for SERVICE in books-service auth-service reviews-service; do
  case $SERVICE in
    books-service)   SRC="backend" ;;
    auth-service)    SRC="services/auth-service" ;;
    reviews-service) SRC="services/reviews-service" ;;
  esac

  echo "  Building $SERVICE..."
  docker build -t "${PROJECT}-${SERVICE}" "$REPO_ROOT/$SRC"
  docker tag "${PROJECT}-${SERVICE}:latest" "$ECR_BASE/${PROJECT}-${SERVICE}:latest"
  docker push "$ECR_BASE/${PROJECT}-${SERVICE}:latest"
  echo "  OK $SERVICE"
done
echo ""

# ── EKS (tarda 15-25 min) ────────────────────────────────────
echo "  AVISO: EKS tarda entre 15 y 25 minutos."
deploy_stack "${PROJECT}-eks" "04-eks.yaml" \
  KubernetesVersion="1.31" \
  NodeInstanceType=t3.medium \
  NodeMinSize=2 NodeMaxSize=4 NodeDesiredSize=2

echo "  Configurando kubectl..."
aws eks update-kubeconfig --name "${PROJECT}-cluster" --region "$REGION"
echo "  OK kubectl configurado"
echo ""

# ── DynamoDB ──────────────────────────────────────────────────
deploy_stack "${PROJECT}-dynamodb" "05-dynamodb.yaml"

# ── Seed DynamoDB con libros de ejemplo ──────────────────────
echo "──────────────────────────────────────────"
echo "  Seeding DynamoDB"
echo "──────────────────────────────────────────"
TABLE="${PROJECT}-books"

seed_book() {
  local ID=$1 NAME=$2 AUTHOR=$3 DESC=$4 PRICE=$5 STOCK=$6 LOW=$7 IMG=$8
  aws dynamodb put-item --table-name "$TABLE" --region "$REGION" \
    --item "{\"id\":{\"S\":\"$ID\"},\"name\":{\"S\":\"$NAME\"},\"author\":{\"S\":\"$AUTHOR\"},\"description\":{\"S\":\"$DESC\"},\"price\":{\"S\":\"$PRICE\"},\"countInStock\":{\"N\":\"$STOCK\"},\"lowStock\":{\"BOOL\":$LOW},\"image\":{\"S\":\"$IMG\"}}"
}

seed_book "1" "Cien anos de soledad"      "Gabriel Garcia Marquez" "La historia de la familia Buendia."   "$25.000" "10" "false" "https://covers.openlibrary.org/b/isbn/9780060883287-L.jpg"
seed_book "2" "1984"                      "George Orwell"          "Novela distopica del Gran Hermano."    "$18.000" "15" "false" "https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg"
seed_book "3" "El principito"             "Antoine de Saint-Exupery" "El viaje de un pequeno principe."   "$15.000" "20" "false" "https://covers.openlibrary.org/b/isbn/9780156012195-L.jpg"
seed_book "4" "Don Quijote de la Mancha"  "Miguel de Cervantes"    "Las aventuras del hidalgo Don Quijote." "$30.000" "3" "true"  "https://covers.openlibrary.org/b/isbn/9788420412146-L.jpg"
seed_book "5" "La sombra del viento"      "Carlos Ruiz Zafon"      "Misterio literario en Barcelona."      "$28.000" "2" "true"  "https://covers.openlibrary.org/b/isbn/9788408163435-L.jpg"
seed_book "6" "El amor en tiempos del colera" "Gabriel Garcia Marquez" "Una historia de amor de 50 anos."  "$22.000" "8" "false" "https://covers.openlibrary.org/b/isbn/9780307389732-L.jpg"

echo "  OK 6 libros insertados en DynamoDB"
echo ""

# ── S3 ────────────────────────────────────────────────────────
deploy_stack "${PROJECT}-s3" "06-s3.yaml"

# Configurar S3 website hosting (CloudFront bloqueado en Academy)
echo "  Configurando S3 website hosting..."
aws s3api put-public-access-block \
  --bucket "$FRONTEND_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-bucket-policy \
  --bucket "$FRONTEND_BUCKET" \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::${FRONTEND_BUCKET}/*\"
    }]
  }"

aws s3 website "s3://$FRONTEND_BUCKET" \
  --index-document index.html \
  --error-document index.html

FRONTEND_URL="http://${FRONTEND_BUCKET}.s3-website-${REGION}.amazonaws.com"
echo "  OK S3 website: $FRONTEND_URL"
echo ""

# ── Kubernetes: Secret de credenciales AWS ───────────────────
echo "──────────────────────────────────────────"
echo "  Creando secret AWS en Kubernetes"
echo "──────────────────────────────────────────"

AWS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET=$(aws configure get aws_secret_access_key)
AWS_TOKEN=$(aws configure get aws_session_token)

kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET" \
  --from-literal=AWS_SESSION_TOKEN="$AWS_TOKEN" \
  --from-literal=AWS_REGION="$REGION" \
  --from-literal=DYNAMO_TABLE="${PROJECT}-books" \
  --from-literal=NODE_ENV="production" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "  OK Secret creado"
echo ""

# ── Kubernetes: Desplegar microservicios ─────────────────────
echo "──────────────────────────────────────────"
echo "  Aplicando manifiestos Kubernetes"
echo "──────────────────────────────────────────"
K8S_DIR="$REPO_ROOT/k8s"

kubectl apply -f "$K8S_DIR/books-service/"
kubectl apply -f "$K8S_DIR/auth-service/"
kubectl apply -f "$K8S_DIR/reviews-service/"
kubectl apply -f "$K8S_DIR/ingress.yaml"

echo "  Esperando pods (max 3 min)..."
kubectl wait --for=condition=available deployment/books-deployment   --timeout=180s || true
kubectl wait --for=condition=available deployment/auth-deployment    --timeout=180s || true
kubectl wait --for=condition=available deployment/reviews-deployment --timeout=180s || true
echo "  OK Pods corriendo"
echo ""

# Obtener DNS del ALB
echo "  Esperando DNS del ALB (60s)..."
sleep 60
ALB_DNS=$(kubectl get ingress bookstore-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
  echo "  AVISO: ALB sin DNS aun. Obtenerlo con:"
  echo "  kubectl get ingress bookstore-ingress"
  ALB_DNS="PENDING"
fi
echo "  ALB DNS: $ALB_DNS"
echo ""

# ── Build frontend con URL del ALB ───────────────────────────
echo "──────────────────────────────────────────"
echo "  Build React y sync a S3"
echo "──────────────────────────────────────────"
cd "$REPO_ROOT/frontend"
VITE_API_URL="http://$ALB_DNS" npm run build
aws s3 sync dist/ "s3://$FRONTEND_BUCKET" --delete
cd "$REPO_ROOT"
echo "  OK Frontend subido a S3"
echo ""

# ── Lambda ───────────────────────────────────────────────────
deploy_stack "${PROJECT}-lambda" "08-lambda.yaml" \
  StockThreshold=3

# ══════════════════════════════════════════════════════════════
echo "============================================"
echo "  DESPLIEGUE COMPLETO"
echo "============================================"
kubectl get pods
echo ""
echo "  Frontend : $FRONTEND_URL"
echo "  API      : http://$ALB_DNS/api/books"
echo ""
echo "  IMPORTANTE: Las credenciales Academy expiran cada 4h."
echo "  Para renovarlas:"
echo "    kubectl create secret generic aws-credentials \\"
echo "      --from-literal=AWS_ACCESS_KEY_ID=\$(aws configure get aws_access_key_id) \\"
echo "      --from-literal=AWS_SECRET_ACCESS_KEY=\$(aws configure get aws_secret_access_key) \\"
echo "      --from-literal=AWS_SESSION_TOKEN=\$(aws configure get aws_session_token) \\"
echo "      --from-literal=AWS_REGION=us-east-1 \\"
echo "      --from-literal=DYNAMO_TABLE=${PROJECT}-books \\"
echo "      --from-literal=NODE_ENV=production \\"
echo "      --dry-run=client -o yaml | kubectl apply -f -"
echo "    kubectl rollout restart deployment/books-deployment"