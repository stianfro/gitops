#!/bin/bash

# TODO: Create check for CLI tools

# echo "Checking minikube status"

# minikube status

# if [ $? -eq 0 ] ; then
#   echo "minikube already running, recreating cluster ..."
#   minikube delete
#   minikube start
#   minikube addons enable ingress
# else
#   echo "Starting minikube"
#   minikube start
#   minikube addons enable ingress
# fi

curl -sfL https://get.k3s.io | sh -
# /usr/local/bin/k3s-uninstall.sh

echo "Set k3s kubeconfig"
sudo cp -v /etc/rancher/k3s/k3s.yaml ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "Current KUBECONFIG: $KUBECONFIG"

echo "Set context to use argocd namespace"
kubectl config set-context default --namespace=argocd

echo "Installing Argo CD Core"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml

POD_STATUS="false"

while [ $POD_STATUS == "false" ] ; do
  kubectl get pod argocd-application-controller-0
  if [ $? -eq 0 ] ; then
    POD_STATUS="true"
  else
    sleep 3
  fi
done

echo "Check Argo CD status before continuing"
kubectl wait --timeout 60s --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd
kubectl wait --timeout 60s --for=condition=ready pod -l app.kubernetes.io/name=argocd-applicationset-controller -n argocd
kubectl wait --timeout 60s --for=condition=ready pod -l app.kubernetes.io/name=argocd-redis -n argocd
kubectl wait --timeout 60s --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd

echo "Setting up Argo CD CLI"
argocd login --core --name default

echo "Add kuma helm repo"
argocd repo add https://kumahq.github.io/charts --type helm --name kuma

echo "Add gitops git repo"
argocd repo add https://github.com/stianfro/gitops --type git --name gitops

echo "Create kuma-system namespace"
kubectl create namespace kuma-system

echo "Installing bootstrap App"
kubectl create -f https://raw.githubusercontent.com/stianfro/gitops/main/bootstrap.yaml

echo "Syncing bootstrap App"
argocd app sync bootstrap

echo "Syncing kuma App"
argocd app sync kuma-standalone

echo "Creating kuma demo application"
kubectl apply -f https://bit.ly/3Kh2Try

echo "Access kuma:"
echo "http://kuma.local/gui"

echo "kubectl in fish:"
echo "set -x KUBECONFIG '`echo ~`/.kube/config'"

echo "Press Enter to continue"
read

echo "Enable kuma mTLS"
echo "apiVersion: kuma.io/v1alpha1
kind: Mesh
metadata:
  name: default
spec:
  mtls:
    enabledBackend: ca-1
    backends:
    - name: ca-1
      type: builtin" | kubectl apply -f -

echo "Installing kuma metrics"
kumactl install metrics | kubectl apply -f -
echo "apiVersion: kuma.io/v1alpha1
kind: Mesh
metadata:
  name: default
spec:
  mtls:
    enabledBackend: ca-1
    backends:
    - name: ca-1
      type: builtin
  metrics:
    enabledBackend: prometheus-1
    backends:
    - name: prometheus-1
      type: prometheus" | kubectl apply -f -


echo "Access Grafana:"
echo "kubectl port-forward svc/grafana -n kuma-metrics 3000:3000 --address 0.0.0.0"


