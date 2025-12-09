#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ArgoCD Bootstrap for Homelab Cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure your kubeconfig is set up correctly"
    exit 1
fi

echo -e "${GREEN}✓${NC} Connected to cluster: $(kubectl config current-context)"
echo ""

# Step 1: Create ArgoCD namespace
echo -e "${BLUE}[1/6]${NC} Creating argocd namespace..."
if kubectl get namespace argocd &> /dev/null; then
    echo -e "${YELLOW}  Namespace 'argocd' already exists${NC}"
else
    kubectl create namespace argocd
    echo -e "${GREEN}  ✓ Namespace created${NC}"
fi
echo ""

# Step 2: Install ArgoCD
echo -e "${BLUE}[2/6]${NC} Installing ArgoCD..."
if kubectl get deployment argocd-server -n argocd &> /dev/null; then
    echo -e "${YELLOW}  ArgoCD is already installed${NC}"
else
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo -e "${GREEN}  ✓ ArgoCD installed${NC}"
fi
echo ""

# Step 3: Wait for ArgoCD to be ready
echo -e "${BLUE}[3/6]${NC} Waiting for ArgoCD to be ready (this may take a few minutes)..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server \
    deployment/argocd-repo-server \
    deployment/argocd-applicationset-controller \
    -n argocd

echo -e "${GREEN}  ✓ ArgoCD is ready${NC}"
echo ""

# Step 4: Apply ArgoCD Project
echo -e "${BLUE}[4/6]${NC} Creating homelab ArgoCD project..."
kubectl apply -f argocd/projects/homelab.yaml
echo -e "${GREEN}  ✓ Project created${NC}"
echo ""

# Step 5: Apply root app (app-of-apps)
echo -e "${BLUE}[5/6]${NC} Deploying root application (app-of-apps)..."
kubectl apply -f argocd/root-app.yaml
echo -e "${GREEN}  ✓ Root application deployed${NC}"
echo ""

# Step 6: Get initial admin password
echo -e "${BLUE}[6/6]${NC} Retrieving ArgoCD admin credentials..."
echo ""
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "N/A")

if [ "$ARGOCD_PASSWORD" != "N/A" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Bootstrap Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}ArgoCD Credentials:${NC}"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo ""
    echo -e "${YELLOW}Access ArgoCD UI:${NC}"
    echo "  1. Port forward:"
    echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo ""
    echo "  2. Open browser:"
    echo "     https://localhost:8080"
    echo ""
    echo -e "${YELLOW}ArgoCD CLI Login:${NC}"
    echo "  argocd login localhost:8080 --username admin --password '$ARGOCD_PASSWORD' --insecure"
    echo ""
    echo -e "${YELLOW}Change Password (Recommended):${NC}"
    echo "  argocd account update-password"
    echo ""
else
    echo -e "${YELLOW}Note: Could not retrieve initial admin password${NC}"
    echo "It may have already been deleted (this is normal after initial login)"
fi

echo -e "${YELLOW}View Applications:${NC}"
echo "  kubectl get applications -n argocd"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Port forward to access the UI"
echo "  2. Login and change the admin password"
echo "  3. Monitor application sync status"
echo "  4. Add more applications by creating files in argocd/apps/"
echo ""
