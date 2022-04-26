#!/bin/bash

echo "Checking minikube status"

minikube status

if [ $? -eq 0 ] ; then
  echo "minikube already running, recreating cluster ..."
  minikube delete
  minikube start
else
  echo "Starting minikube"
  minikube start
fi

echo "Set context to use argocd namespace"
kubectl config set-context minikube --namespace=argocd

echo "Installing Argo CD Core"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml

echo "Check Argo CD status before continuing"

ARGO_READY="false"

while [ $ARGO_READY == "false"  ] ; do
  kubectl get pods -n argocd | grep -v NAME | grep -v Running
  if [ $? -eq 1 ] ; then
    echo "..."
  else
    echo "Ready, continuing"
    ARGO_READY='true'
  fi
done

echo "Setting up Argo CD CLI"
argocd login --core --name minikube

echo "Add minikube as cluster"
argocd cluster add minikube --yes

echo "Installing kuma standalone"
kubectl create -f https://raw.githubusercontent.com/stianfro/gitops/main/kuma/standalone.yaml

echo "Access kuma:"
echo "kubectl port-forward svc/kuma-control-plane -n kuma-system 5681:5681"
echo "http://127.0.0.1:5681/gui"
echo ""
