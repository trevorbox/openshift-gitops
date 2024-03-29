# The app of apps pattern

This example uses helm charts.

## setup

### deploy operators

```sh
helm upgrade -i openshift-pipelines-operator setup/helm/openshift-pipelines-operator/ -n openshift-operators
```

```sh
helm upgrade -i openshift-gitops-operator setup/helm/openshift-gitops-operator/ -n openshift-operators
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
helm upgrade -i cicd setup/helm/argocd/ -n ${argo_namespace} --create-namespace
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

## build pipeline

```sh
export build_namespace=${org}-${context}-build
```

```sh
helm upgrade -i go-build-and-deploy pipelines/helm/build -n ${build_namespace} \
  --set-file quay.dockerconfigjson=${XDG_RUNTIME_DIR}/containers/auth.json \
  --set-file github.ssh.id_rsa=${HOME}/.ssh/tkn/id_ed25519 \
  --set-file github.ssh.known_hosts=${HOME}/.ssh/known_hosts \
  --set argocd.server=argocd-server.${argo_namespace}.svc.cluster.local \
  --set argocd.username=admin \
  --set argocd.password=$(oc get secret argocd-cluster -n ${argo_namespace} -o jsonpath={.data.admin\\.password} | base64 -d) \
  --create-namespace
oc apply -f pipelines/pipelinerun/pipelinerun-build-deploy-go.yaml -n ${build_namespace}
```

## build from base image change

### build the trigger pipelinerun image

```sh
helm upgrade -i build-base-image-trigger pipelines/helm/build-base-image-trigger -n ${build_namespace}
```

### deploy the trigger

> Note: The BuildConfig is configured to trigger whenever the builder or base ImageStreamTags import new latest images (scheduled every 15 minutes by default).

```sh
helm upgrade -i base-image-trigger pipelines/helm/base-image-trigger -n ${build_namespace}
```

```sh
helm delete base-image-trigger -n ${build_namespace}
```

## cleanup

```sh
helm delete rootapp -n ${argo_namespace}
for i in "${envs[@]}"; do ns=${org}-${context}-${i} && oc delete project ${ns}; done
```
