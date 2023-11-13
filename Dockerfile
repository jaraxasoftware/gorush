FROM plugins/base:linux-amd64

LABEL org.label-schema.version=latest
LABEL org.label-schema.vcs-url="https://github.com/jaraxasoftware/gorush.git"
LABEL org.label-schema.name="Gorush"
LABEL org.label-schema.vendor="jaraxa Software"
LABEL org.label-schema.schema-version="1.0"
LABEL org.opencontainers.image.source https://github.com/jaraxasoftware/gorush

RUN addgroup -g 1000 -S gorush && \
    adduser -u 1000 -g 1000 -S -H gorush

COPY --chown=1000:1000 release/linux/amd64/gorush /bin/

HEALTHCHECK --start-period=2s --interval=10s --timeout=5s \
  CMD ["/bin/gorush", "--ping"]

ENTRYPOINT ["/bin/gorush", "-c", "/config/config.yml"]

USER 1000:1000
