k3d c --n gitops -p 8001:80 --auto-restart -x --no-deploy=traefik 
k3d add-node -n gitops --role agent --count 2 
export KUBECONFIG="$(k3d get-kubeconfig --name='gitops')"   


REPO_ROOT=$(git rev-parse --show-toplevel)

curl -s https://istio.io/operator.yaml | grep -v '\.\.\.' > ${REPO_ROOT}/istio/operator.yaml



helm -n fluxcd delete flux
kubectl -n istio-system delete istiooperators.install.istio.io --all
helm -n fluxcd delete helm-operator
helm -n istio-system delete flagger
helm -n istio-system delete flagger-grafana
kubectl delete ns istio-system
kubectl delete ns istio-operator
kubectl delete ns fluxcd