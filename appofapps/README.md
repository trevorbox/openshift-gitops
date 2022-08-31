# The app of apps pattern

This example uses helm charts.

## setup

### deploy operators

> TODO add openshift-pipelines operator installation chart

```sh
helm upgrade -i openshift-gitops-operator setup/argocd/helm/openshift-gitops-operator/ -n openshift-operators
# delete default controller in openshift-gitops namespace if not needed
oc delete gitopsservice cluster -n openshift-gitops
```

### create namespaces and setup vars

```sh
export argo_namespace=cicd
export envs=( dev build qa perf prod )
export context=echo
export org=hr

for i in "${envs[@]}"; do ns=${org}-${context}-${i} && oc new-project ${ns} && oc label namespace ${ns} argocd.argoproj.io/managed-by=${argo_namespace}; done
```

> Note: there should be a Group created that your User belongs to and defined in the ArgoCD CR's spec.rbac section to allow your user admin access

example ArgoCD CR spec.rbac snippet:

```yaml
  rbac:
    defaultPolicy: ''
    policy: |
      g, cluster-admins, role:admin
    scopes: '[groups]'
```

### deploy argocd

```sh
helm upgrade -i cicd setup/argocd/helm/argocd/ -n ${argo_namespace} --create-namespace
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

## build pipeline

```sh
export build_namespace=${org}-${context}-build
```

```sh
helm upgrade -i go-build-and-deploy pipelines/helm/build -n ${build_namespace} \
  --set-file quay.dockerconfigjson=trevorbox-deployer-auth.json \
  --set-file github.ssh.id_rsa=${HOME}/.ssh/tkn/id_ed25519 \
  --set-file github.ssh.known_hosts=${HOME}/.ssh/known_hosts \
  --set argocd.server=argocd-server.${argo_namespace}.svc.cluster.local \
  --set argocd.username=admin \
  --set argocd.password=$(oc get secret argocd-cluster -n ${argo_namespace} -o jsonpath={.data.admin\\.password} | base64 -d) \
  --create-namespace
oc apply -f pipelines/pipelinerun/pipelinerun-build-deploy-go.yaml -n ${build_namespace}
```
