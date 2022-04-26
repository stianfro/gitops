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

POD_STATUS="false"

while [ $POD_STATUS == "false" ] ; do
  kubectl get pod argocd-application-controller-0
  if [ $? -eq 0 ] ; then
    POD_STATUS="true"
  fi
done

echo "Check Argo CD status before continuing"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-applicationset-controller -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-redis -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd

echo "Setting up Argo CD CLI"
argocd login --core --name minikube

echo "Add kuma helm repo"
argocd repo add https://kumahq.github.io/charts --type helm --name kuma

echo "Installing kuma standalone"
kubectl create -f https://raw.githubusercontent.com/stianfro/gitops/main/kuma/standalone.yaml

echo "Access kuma:"
echo "kubectl port-forward svc/kuma-control-plane -n kuma-system 5681:5681"
echo "http://127.0.0.1:5681/gui"
echo ""
