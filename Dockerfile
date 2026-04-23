# CHIA BUILD STEP
FROM python:3.13-slim AS chia_build

ARG BRANCH="2.7.0"
ARG COMMIT=""

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        lsb-release sudo git

WORKDIR /chia-blockchain

RUN echo "cloning ${BRANCH}" && \
    git clone --depth 1 --branch ${BRANCH} --recurse-submodules=mozilla-ca https://github.com/Chia-Network/chia-blockchain.git . && \
    # If COMMIT is set, check out that commit, otherwise just continue
    ( [ ! -z "$COMMIT" ] && git fetch origin $COMMIT && git checkout $COMMIT ) || true && echo "running build-script" && \
    /bin/sh ./install.sh -s

FROM mikefarah/yq:4 AS yq

# IMAGE BUILD
FROM python:3.13-slim AS chia_node

EXPOSE 8555 8444

ENV CHIA_ROOT=/chia-data
ENV CHIA_PREFER_IPV6=false
ENV service="node"
ENV testnet="false"
ENV network="mainnet"
ENV TZ="UTC"
ENV upnp="false"
ENV log_to_file="true"
ENV log_level="INFO"
ENV healthcheck="true"
ENV create_datastore="false"
ENV use_checkpoint="true"
ENV chia_args=""

# Minimal list of software dependencies
#   sudo: Needed for alternative plotter install
#   tzdata: Setting the timezone
#   curl: Health-checks
#   netcat: Healthchecking the daemon
#   yq: changing config settings
#   aria2: used to grab the DB snapshot for syncing

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y sudo tar tzdata curl netcat-traditional aria2 && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

RUN echo "net.core.rmem_max = 4194304" >> /etc/sysctl.conf
RUN echo "net.core.wmem_max = 1048576" >> /etc/sysctl.conf

COPY --chmod=0755 --from=yq /usr/bin/yq /usr/bin/yq
COPY --chmod=0755 --from=chia_build /chia-blockchain /chia-blockchain

ENV PATH=/chia-blockchain/venv/bin:/usr/local/bin/:$PATH
WORKDIR /chia-blockchain

COPY --chmod=0755 docker-start.sh /usr/local/bin/
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/
COPY --chmod=0755 docker-healthcheck.sh /usr/local/bin/

HEALTHCHECK --interval=1m --timeout=10s --start-period=5m \
  CMD /bin/bash /usr/local/bin/docker-healthcheck.sh || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["docker-start.sh"]