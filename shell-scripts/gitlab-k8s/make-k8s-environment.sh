#!/bin/bash
PROJECT_NAME="${1}"
PROJECT_ENVIRONMENT="${2}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
  echo -e "${RED}Usage: ${GREEN}$0 <PROJECT_NAME> <PROJECT_ENVIRONMENT>${NC}"
}

if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_ENVIRONMENT" ]; then
  usage
  exit 1
fi

base64_decode_key() {
  if [[ "$OSTYPE" == "linux"* ]]; then
    echo "-d"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "-D"
  else
    echo "--help"
  fi
}

NS="${PROJECT_NAME}-${PROJECT_ENVIRONMENT}" # K8s namespace
SA="${PROJECT_NAME}-${PROJECT_ENVIRONMENT}" # Service account
ROLE="${PROJECT_NAME}-${PROJECT_ENVIRONMENT}"
ROLEBIND="${PROJECT_NAME}-${PROJECT_ENVIRONMENT}"

# Create namespace
if kubectl get ns "$NS" 2>/dev/null; then
  echo -e "${GREEN}namespace $NS for project already exists${NC}"
  echo
else
  echo -e "${GREEN}creating namespace for project${NC}"
  kubectl create namespace "$NS"
  echo
fi

# Create service account
if kubectl -n "$NS" get sa "$SA" 2>/dev/null; then
  echo -e "${GREEN}serviceaccount for project already exists${NC}"
  echo
else
  echo
  echo -e "${GREEN}creating CI serviceaccount for project${NC}"
  kubectl create serviceaccount \
    --namespace "$NS" \
    "$SA"
  echo -e "${GREEN}Create long-lived API token for a ServiceAccount${NC}"
  cat <<EOF | kubectl apply --namespace "$NS" -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: ${SA}
        annotations:
          kubernetes.io/service-account.name: ${SA}
      type: kubernetes.io/service-account-token
EOF
  echo
fi

# Create Authorization role
if kubectl -n "$NS" get role "$ROLE" 2>/dev/null; then
  echo -e "${GREEN}role for project already exists${NC}"
  echo
else
  echo -e "${GREEN}creating CI role for project${NC}"
  cat <<EOF | kubectl apply --namespace "$NS" -f -
        apiVersion: rbac.authorization.k8s.io/v1
        kind: Role
        metadata:
          name: "$ROLE"
        rules:
        - apiGroups: ["", "extensions", "apps", "batch", "events", "networking.k8s.io", "certmanager.k8s.io", "cert-manager.io", "monitoring.coreos.com", "autoscaling"]
          resources: ["*"]
          verbs: ["*"]
EOF
  echo
fi

# Binding role
if kubectl -n "$NS" get rolebinding "$ROLEBIND" 2>/dev/null; then
  echo -e "${GREEN}rolebinding for project already exists${NC}"
  echo
else
  echo -e "${GREEN}creating CI rolebinding for project${NC}"
  kubectl create rolebinding \
    --namespace "$NS" \
    --serviceaccount "$NS":"$SA" \
    --role "$ROLE" \
    "$ROLEBIND"
  echo
fi

# Get token
echo -e "${GREEN}access token for new CI user:${NC}"
kubectl -n "$NS" describe secrets/"${SA}" | grep 'token: '
