FROM debian:bookworm-slim
RUN groupadd --system logtool && useradd --system --gid logtool --no-create-home logtool
COPY --chmod=755 logtool.sh /usr/local/bin/logtool
USER logtool
WORKDIR /tmp
ENTRYPOINT ["/usr/local/bin/logtool"]
