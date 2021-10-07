FROM alpine/helm:3.7.0
ENV OPERATOR_SDK_VERSION=v1.13.0
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
            bash \
            ca-certificates \
            curl \
            git \
            make \
            tree \
            yq
RUN curl -sLo /usr/bin/operator-sdk https://github.com/operator-framework/operator-sdk/releases/download/$OPERATOR_SDK_VERSION/operator-sdk_linux_amd64 && \
		chmod +x /usr/bin/operator-sdk && \
    curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh  | bash && \
    mv kustomize /usr/bin/


COPY generate.sh /generate.sh
COPY Makefile /Makefile
ENTRYPOINT [""]
CMD ["/generate.sh"]

# To verify the script locally, run:
# docker build -t testfoo .
# docker run -ti --rm \
#     -e CLONE_REPO="true" \
#     -e GIT_TARGET_REVISION="operatorhub" \
#     -e PRE_GENERATE_HOOK="make -f /Makefile deployment-blueprint" \
#     -e POST_GENERATE_HOOK="make -f /Makefile bundle-add-examples bundle-add-crd-info" \
#     -e PREPARE_HELM_COMMAND="helm repo add coredns https://absaoss.github.io/coredns-helm --insecure-skip-tls-verify && cd ./chart/k8gb && helm dependency update" \
#     -e HELM_COMMAND="helm -n placeholder template ./chart/k8gb --name-template=k8gb --set k8gb.securityContext.runAsUser=null  --set k8gb.log.format=simple --set k8gb.log.level=info" \
#     testfoo /generate.sh k8gb-io/k8gb 0.0.1