#!/usr/bin/env zsh
set -euo pipefail

# Configurable variables
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-e4420dbb-ea34-41cf-b047-230c73836759}"
AKS_ID="${AKS_ID:-/subscriptions/e4420dbb-ea34-41cf-b047-230c73836759/resourceGroups/hsun-private-cni-aks-rg/providers/Microsoft.ContainerService/managedClusters/hsun-k8s}"
RG_NAME="${RG_NAME:-fullstack-ai-rg}"
LOCATION="${LOCATION:-eastus}"
ACR_NAME="${ACR_NAME:-hsunfullstackacr}"
AOAI_NAME="${AOAI_NAME:-hsun-aoai}"
AOAI_SKU="${AOAI_SKU:-S0}"
AOAI_MODEL="${AOAI_MODEL:-}"
AOAI_MODEL_VERSION="${AOAI_MODEL_VERSION:-}"  # will be auto-selected if empty
AOAI_DEPLOYMENT="${AOAI_DEPLOYMENT:-gpt4o-mini}"
AOAI_API_VERSION="${AOAI_API_VERSION:-2024-07-01-preview}"
NAMESPACE="${NAMESPACE:-fullstack}"

BACKEND_IMAGE_TAG="${BACKEND_IMAGE_TAG:-latest}"
FRONTEND_IMAGE_TAG="${FRONTEND_IMAGE_TAG:-latest}"

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"

echo "Setting subscription"
az account set --subscription "$SUBSCRIPTION_ID"

# Parse AKS info early
AKS_RG=$(echo "$AKS_ID" | awk -F/ '{for(i=1;i<=NF;i++){if($i=="resourceGroups"){print $(i+1);break}}}')
AKS_NAME=$(echo "$AKS_ID" | awk -F/ '{for(i=1;i<=NF;i++){if($i=="managedClusters"){print $(i+1);break}}}')

echo "Ensuring resource group $RG_NAME in $LOCATION"
az group create -n "$RG_NAME" -l "$LOCATION" -o none

echo "Ensuring ACR $ACR_NAME"
if ! az acr show -n "$ACR_NAME" -g "$RG_NAME" &>/dev/null; then
  az acr create -n "$ACR_NAME" -g "$RG_NAME" --sku Standard -o none
fi
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" -g "$RG_NAME" --query loginServer -o tsv)

echo "Grant AKS pull on ACR (best-effort)"
if ! az aks update -n "$AKS_NAME" -g "$AKS_RG" --attach-acr "$ACR_NAME" -o none; then
  echo "Not owner or attach failed; will use imagePullSecret"
fi

echo "Ensuring Azure OpenAI $AOAI_NAME"
if ! az cognitiveservices account show -n "$AOAI_NAME" -g "$RG_NAME" &>/dev/null; then
  az cognitiveservices account create \
    -n "$AOAI_NAME" -g "$RG_NAME" -l "$LOCATION" \
    --kind OpenAI --sku "$AOAI_SKU" --custom-domain "$AOAI_NAME" -o none
fi

AOAI_ENDPOINT=$(az cognitiveservices account show -n "$AOAI_NAME" -g "$RG_NAME" --query properties.endpoint -o tsv)
AOAI_KEY=$(az cognitiveservices account keys list -n "$AOAI_NAME" -g "$RG_NAME" --query key1 -o tsv)

if [ -z "$AOAI_MODEL" ] || [ -z "$AOAI_MODEL_VERSION" ]; then
  echo "Auto-selecting supported Azure OpenAI model in region..."
  CANDIDATES=(gpt-4o gpt-4o-mini gpt-4.1 gpt-4-turbo gpt-35-turbo)
  for C in ${CANDIDATES[@]}; do
    VER=$(az cognitiveservices account list-models -g "$RG_NAME" -n "$AOAI_NAME" \
      --query "[?format=='OpenAI' && name=='$C'] | [0].version" -o tsv || true)
    if [ -n "$VER" ]; then
      AOAI_MODEL="$C"
      AOAI_MODEL_VERSION="$VER"
      break
    fi
  done
  if [ -z "$AOAI_MODEL" ] || [ -z "$AOAI_MODEL_VERSION" ]; then
    echo "No suitable model found in this region/account. Please set AOAI_MODEL and AOAI_MODEL_VERSION env vars."
    exit 1
  fi
fi

echo "Ensuring model deployment $AOAI_DEPLOYMENT -> $AOAI_MODEL:$AOAI_MODEL_VERSION"
if ! az cognitiveservices account deployment show -g "$RG_NAME" -n "$AOAI_NAME" --deployment-name "$AOAI_DEPLOYMENT" &>/dev/null; then
  az cognitiveservices account deployment create \
    -g "$RG_NAME" -n "$AOAI_NAME" \
    --deployment-name "$AOAI_DEPLOYMENT" \
    --model-format OpenAI \
  --model-name "$AOAI_MODEL" \
  --model-version "$AOAI_MODEL_VERSION" \
  --sku-capacity 1 -o none
fi

echo "Building images in ACR (cloud build)"
az acr build -r "$ACR_NAME" -t backend:"$BACKEND_IMAGE_TAG" "$ROOT_DIR/backend"
az acr build -r "$ACR_NAME" -t frontend:"$FRONTEND_IMAGE_TAG" "$ROOT_DIR/frontend"

echo "Getting AKS credentials"
az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --overwrite-existing -o none

echo "Creating namespace and base config"
kubectl apply -f "$ROOT_DIR/k8s/namespace.yaml"
kubectl apply -f "$ROOT_DIR/k8s/databases.yaml"
kubectl apply -f "$ROOT_DIR/k8s/backend-configmap.yaml"

echo "Creating/Updating backend secret with Azure OpenAI"
kubectl -n "$NAMESPACE" apply -f "$ROOT_DIR/k8s/backend-secret.yaml" || true
kubectl -n "$NAMESPACE" create secret generic backend-secrets \
  --from-literal=AZURE_OPENAI_ENDPOINT="$AOAI_ENDPOINT" \
  --from-literal=AZURE_OPENAI_API_KEY="$AOAI_KEY" \
  --from-literal=AZURE_OPENAI_DEPLOYMENT="$AOAI_DEPLOYMENT" \
  --from-literal=AZURE_OPENAI_API_VERSION="$AOAI_API_VERSION" \
  --dry-run=client -o yaml | kubectl -n "$NAMESPACE" apply -f -

echo "Rendering manifests with image names"
BACKEND_MANIFEST=$(mktemp)
FRONTEND_MANIFEST=$(mktemp)
sed "s#REPLACE_BACKEND_IMAGE#$ACR_LOGIN_SERVER/backend:$BACKEND_IMAGE_TAG#g" "$ROOT_DIR/k8s/backend.yaml" > "$BACKEND_MANIFEST"
sed "s#REPLACE_FRONTEND_IMAGE#$ACR_LOGIN_SERVER/frontend:$FRONTEND_IMAGE_TAG#g" "$ROOT_DIR/k8s/frontend.yaml" > "$FRONTEND_MANIFEST"

echo "Creating/Refreshing ACR pull secret"
if ! kubectl -n "$NAMESPACE" get secret acr-pull-secret &>/dev/null; then
  kubectl -n "$NAMESPACE" create secret docker-registry acr-pull-secret \
    --docker-server="$ACR_LOGIN_SERVER" \
    --docker-username="00000000-0000-0000-0000-000000000000" \
    --docker-password="$(az acr login --name "$ACR_NAME" --expose-token --output tsv --query accessToken)" \
    --docker-email="unused@example.com"
else
  kubectl -n "$NAMESPACE" delete secret acr-pull-secret || true
  kubectl -n "$NAMESPACE" create secret docker-registry acr-pull-secret \
    --docker-server="$ACR_LOGIN_SERVER" \
    --docker-username="00000000-0000-0000-0000-000000000000" \
    --docker-password="$(az acr login --name "$ACR_NAME" --expose-token --output tsv --query accessToken)" \
    --docker-email="unused@example.com"
fi

echo "Deploying backend and frontend"
kubectl apply -f "$BACKEND_MANIFEST"
kubectl apply -f "$FRONTEND_MANIFEST"

echo "Waiting for services to get external IPs"
echo "Backend service:"
kubectl -n "$NAMESPACE" get svc backend -w &
BACK_PID=$!
sleep 10
kill $BACK_PID || true

echo "Frontend service:"
kubectl -n "$NAMESPACE" get svc frontend -w &
FRONT_PID=$!
sleep 10
kill $FRONT_PID || true

# Patch frontend to point to backend external IP for browser access
echo "Patching frontend env to use backend external IP"
BACKEND_IP=$(kubectl -n "$NAMESPACE" get svc backend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
if [ -n "$BACKEND_IP" ]; then
  kubectl -n "$NAMESPACE" set env deployment/frontend VITE_API_BASE_URL="http://$BACKEND_IP:8000" || true
  kubectl -n "$NAMESPACE" rollout restart deployment/frontend || true
  echo "Frontend will call backend at http://$BACKEND_IP:8000"
else
  echo "Backend external IP not ready yet. You can run: kubectl -n $NAMESPACE get svc backend -o wide"
fi

echo "Done. Query External IPs with: kubectl -n $NAMESPACE get svc"
