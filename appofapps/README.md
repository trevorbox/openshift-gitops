# The app of apps pattern

This example uses helm charts.

## assumptions

1. you have already created the argocd controller using the openshift gitops operator
2. there is a Group created that your User belongs to and defined in the ArgoCD CR's spec.rbac section to allow your user admin access

example ArgoCD CR spec.rbac snippet:

```yaml
  rbac:
    defaultPolicy: ''
    policy: |
      g, cluster-admins, role:admin
    scopes: '[groups]'
```

## setup

```sh
export argo_namespace=cicd
export envs=( dev build qa perf prod )
export context=echo
export org=hr

for i in "${envs[@]}"; do ns=${org}-${context}-${i} && oc new-project ${ns} && oc label namespace ${ns} argocd.argoproj.io/managed-by=${argo_namespace}; done
```

## deploy

```sh
# dev cluster rootapp
helm upgrade -i rootapp argocd/helm/rootapp/ -n ${argo_namespace} \
  --set org=${org} \
  --set context=${context} \
  -f argocd/helm/rootapp/values-cluster-dev.yaml
# stage cluster rootapp
helm upgrade -i rootapp argocd/helm/rootapp/ -n ${argo_namespace} \
  --set org=${org} \
  --set context=${context} \
  -f argocd/helm/rootapp/values-cluster-stage.yaml
# prod cluster rootapp
helm upgrade -i rootapp argocd/helm/rootapp/ -n ${argo_namespace} \
  --set org=${org} \
  --set context=${context} \
  -f argocd/helm/rootapp/values-cluster-prod.yaml
```

## cleanup

```sh
helm delete rootapp -n ${argo_namespace}
for i in "${envs[@]}"; do ns=${org}-${context}-${i} && oc delete project ${ns}; done
```
