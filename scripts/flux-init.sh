#!/usr/bin/env bash

set -e

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl not found"
    exit 1
fi

if [[ ! -x "$(command -v helm)" ]]; then
    echo "helm not found"
    exit 1
fi

git_ssh_url() {
    # shellcheck disable=SC2001
   git config --get remote.origin.url | sed -e 's#^https://github.com/#git@github.com:#'
}

REPO_GIT_INIT_PATHS="istio"
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_URL=${git_ssh_url}
REPO_BRANCH=$(git symbolic-ref --short HEAD)

helm repo add fluxcd https://charts.fluxcd.io

echo ">>> Installing Flux for ${REPO_URL} only watching istio paths"
kubectl create ns flux || true
helm upgrade -i flux fluxcd/flux --wait \
--set git.url=${REPO_URL} \
--set git.branch=${REPO_BRANCH} \
--set git.path=${REPO_GIT_INIT_PATHS} \
--set git.pollInterval=1m \
--set registry.pollInterval=1m \
--set sync.state=secret \
--set syncGarbageCollection.enabled=true \
--namespace fluxcd

echo ">>> Installing Helm Operator"
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
helm upgrade -i helm-operator fluxcd/helm-operator --wait \
--set git.ssh.secretName=flux-git-deploy \
--set helm.versions=v3 \
--namespace fluxcd

echo ">>> GitHub deploy key"
kubectl -n fluxcd logs deployment/flux | grep identity.pub | cut -d '"' -f2

# wait until flux is able to sync with repo
echo ">>> Waiting on user to add above deploy key to Github with write access"
until kubectl logs -n fluxcd deployment/flux | grep event=refreshed
do
  sleep 5
done
echo ">>> Github deploy key is ready"

# wait until sidecar injector webhook is ready before enabled prod namespace on flux
echo ">>> Waiting for istiod to start"
until kubectl -n istio-system get deploy istiod | grep "1/1"
do
  sleep 5
done
echo ">>> Istio control plane is ready"

echo ">>> Configuring Flux for ${REPO_URL}"
helm upgrade -i flux fluxcd/flux --wait \
--set git.url=${REPO_URL} \
--set git.branch=${REPO_BRANCH} \
--set git.path="" \
--set git.pollInterval=1m \
--set registry.pollInterval=1m \
--set sync.state=secret \
--set syncGarbageCollection.enabled=true \
--namespace fluxcd

echo ">>> Cluster bootstrap done!"