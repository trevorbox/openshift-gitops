FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
ARG tkn_dl_link=https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64.tar.gz
ARG oc_dl_link=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.11/openshift-client-linux.tar.gz
COPY build.sh /usr/bin/build.sh
RUN microdnf -y install jq tar && \
    microdnf clean all -y && \
    curl -s $tkn_dl_link | tar xvz -C /usr/bin --no-same-owner tkn && \
    curl -s $oc_dl_link | tar xvz -C /usr/bin --no-same-owner oc && \
    chmod 755 /usr/bin/build.sh
ENTRYPOINT [ "/usr/bin/build.sh" ]
