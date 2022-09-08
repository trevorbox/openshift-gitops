#!/usr/bin/bash

set -ex

# extract image that caused image change trigger
TRIGGERED_BY_IMAGE=$(echo "$BUILD" | jq -j '.spec.triggeredBy[0].imageChangeBuild.imageID')
[ "$TRIGGERED_BY_IMAGE" != "null" ] && FROM_IMAGE="$TRIGGERED_BY_IMAGE"
if [ -n "$FROM_IMAGE" ]; then
    # ... and use it as FROM in buildah build
    BUILD_EXTRA_ARGS="${BUILD_EXTRA_ARGS:+${BUILD_EXTRA_ARGS} }--from $FROM_IMAGE"
fi

BUILD_KIND=$(echo "$BUILD" | jq -j '.kind')
BUILD_API_VERSION=$(echo "$BUILD" | jq -j '.apiVersion')
BUILD_NAME=$(echo "$BUILD" | jq -j '.metadata.name')
BUILD_UID=$(echo "$BUILD" | jq -j '.metadata.uid')

PR_NAME=$(oc create -f - << __EOF__ | sed 's/pipelinerun\.tekton\.dev\/\(.*\) created/\1/'
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: ${NAME_PREFIX}-
  ownerReferences:
  - apiVersion: "${BUILD_API_VERSION}"
    kind: "${BUILD_KIND}"
    name: "${BUILD_NAME}"
    uid: "${BUILD_UID}"
spec:
  pipelineRef:
    name: build-and-deploy
  serviceAccountName: skopeo
  params:
  - name: git-url
    value: ${GIT_URL}
  - name: git-revision
    value: ${GIT_REVISION}
  - name: IMAGE
    value: ${IMAGE}
  - name: CONTEXT
    value: ${CONTEXT}
  - name: GROUP_EMAIL
    value: ${GROUP_EMAIL}
  - name: builder-image-repository
    value: ${BUILDER_IMAGE_REPOSITORY}
  - name: builder-image-tag
    value: ${BUILDER_IMAGE_TAG}
  - name: base-image-repository
    value: ${BASE_IMAGE_REPOSITORY}
  - name: base-image-tag
    value: ${BASE_IMAGE_TAG}
  - name: monorepo-git-url
    value: ${MONOREPO_GIT_URL}
  - name: monorepo-git-revision
    value: ${MONOREPO_GIT_REVISION}
  - name: files
    value:
      - "./appofapps/deploy/helm/app/values-build.yaml"
      - "./appofapps/deploy/helm/app/values-dev.yaml"
  - name: application-names
    value:
      - "hr-echo-dev"
      - "hr-echo-build"
  workspaces:
  - name: shared-workspace
    persistentVolumeClaim:
      claimName: ${SHARED_WORKSPACE_PVC_NAME}
  - name: monorepo-workspace
    persistentVolumeClaim:
      claimName: ${MONOREPO_WORKSPACE_PVC_NAME}
  - name: ssh-creds
    secret:
      secretName: ${SSH_CREDENTIALS_SECRET_NAME}
__EOF__
)
tkn pipelinerun logs --follow "$PR_NAME"
COMPLETION_REASON="$(oc get pipelinerun/${PR_NAME} -o jsonpath='{.status.conditions[0].reason}')"
test "$COMPLETION_REASON" == "Succeeded" && exit 0
test "$COMPLETION_REASON" == "Completed" && exit 0
exit 1