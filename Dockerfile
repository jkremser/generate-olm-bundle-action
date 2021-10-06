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
		chmod +x /usr/bin/operator-sdk

COPY generate.sh /generate.sh
COPY Makefile /Makefile
ENTRYPOINT [""]
CMD ["/generate.sh"]