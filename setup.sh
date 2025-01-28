#!/bin/bash

usage() {
  echo "Usage: $0 [--dashboard]"
  echo "  --dashboard  : Enable dashboard token creation and port forwarding."
  exit 1
}

ENABLE_DASHBOARD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dashboard)
      ENABLE_DASHBOARD=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

helm_release_exists() {
  helm list -n "$1" | grep -q "$2"
}

if [[ ! -f ./kubeconfig ]]; then
  echo "No kubeconfig file found. Copying from kind-manager container..."
  docker cp kind-manager:/root/.kube/config ./kubeconfig
else
  echo "kubeconfig file found."
fi

docker cp kind-manager:/root/.kube/config ./kubeconfig
echo "Current directory: $(pwd)"
echo "KUBECONFIG value: $(pwd)/kubeconfig"

# Export KUBECONFIG with quotes to handle spaces/special characters
export KUBECONFIG="$(pwd)/kubeconfig"

# Verify the export
echo "KUBECONFIG after export: $KUBECONFIG"

# Variables
SERVICE_ACCOUNT_NAME="dashboard-admin"
NAMESPACE="kubernetes-dashboard"
CLUSTER_ROLE_BINDING_NAME="dashboard-admin"
CLUSTER_ROLE="cluster-admin"
POD_NAME_PREFIX="kubernetes-dashboard-kong"


if ! command_exists kubectl; then
  echo "kubectl not found. Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  echo "kubectl installed successfully."
else
  echo "kubectl is already installed."
fi

if ! command_exists helm; then
  echo "Helm not found. Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "Helm installed successfully."
else
  echo "Helm is already installed."
fi


if ! helm repo list | grep -q "kubernetes-dashboard"; then
  echo "Adding Kubernetes Dashboard Helm repository..."
  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
else
  echo "Kubernetes Dashboard Helm repository is already added."
fi


#echo "Updating Helm repositories..."
#helm repo update


if ! helm_release_exists kubernetes-dashboard kubernetes-dashboard; then
  echo "Installing Kubernetes Dashboard..."
  helm upgrade \
    --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    --create-namespace --namespace kubernetes-dashboard
else
  echo "Kubernetes Dashboard is already installed."
fi


if kubectl get serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "ServiceAccount '$SERVICE_ACCOUNT_NAME' exists in namespace '$NAMESPACE'."
else
  echo "ServiceAccount '$SERVICE_ACCOUNT_NAME' does NOT exist in namespace '$NAMESPACE'. Creating it..."
  kubectl create serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE"
fi


if kubectl get clusterrolebinding "$CLUSTER_ROLE_BINDING_NAME" > /dev/null 2>&1; then
  echo "ClusterRoleBinding '$CLUSTER_ROLE_BINDING_NAME' already exists."
else
  echo "ClusterRoleBinding '$CLUSTER_ROLE_BINDING_NAME' does NOT exist. Creating it..."
  kubectl create clusterrolebinding "$CLUSTER_ROLE_BINDING_NAME" \
    --clusterrole="$CLUSTER_ROLE" \
    --serviceaccount="$NAMESPACE:$SERVICE_ACCOUNT_NAME"
fi


check_pod_status() {
  kubectl -n "$NAMESPACE" get pods | awk -v prefix="$POD_NAME_PREFIX" '$0 ~ prefix {print $1, $2, $3}'
}


echo "Checking the status of pods with prefix '$POD_NAME_PREFIX'..."
while true; do
  POD_STATUS=$(check_pod_status)
  if [[ -n "$POD_STATUS" ]]; then
    echo "Pod status:"
    echo "$POD_STATUS"
    # Check if the pod is running and ready
    if echo "$POD_STATUS" | grep -q "1/1.*Running"; then
      echo "Pod '$POD_NAME_PREFIX' is ready."
      break
    else
      echo "Pod '$POD_NAME_PREFIX' is not ready yet. Retrying in 10 seconds..."
    fi
  else
    echo "No pod found with prefix '$POD_NAME_PREFIX'. Retrying in 10 seconds..."
  fi
  sleep 10
done


if [[ "$ENABLE_DASHBOARD" == true ]]; then
  echo "Creating token for 'dashboard-admin'..."
  kubectl -n kubernetes-dashboard create token dashboard-admin

  echo "Forwarding port 8443 to service 'kubernetes-dashboard-kong-proxy'..."
  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
fi

echo "Kubernetes Dashboard setup complete."
