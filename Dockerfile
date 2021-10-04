FROM alpine/helm:3.7.0
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
            yq \
            make \
            bash \
            git \
            ca-certificates
COPY generate.sh /generate.sh
COPY Makefile /Makefile
ENTRYPOINT ["/generate.sh"]