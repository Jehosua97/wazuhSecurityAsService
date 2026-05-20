FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apache2 \
      apt-transport-https \
      ca-certificates \
      curl \
      dbus-x11 \
      gnupg \
      iproute2 \
      iputils-ping \
      mariadb-server \
      net-tools \
      nftables \
      nmap \
      openssl \
      procps \
      python3 \
      rsyslog \
      sudo \
      tmux \
      unzip \
      wget \
      wireguard-tools \
      xauth \
      xorgxrdp \
      xrdp \
      xfce4 \
      xfce4-goodies && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/local-endpoint-entrypoint.sh
RUN chmod 755 /usr/local/bin/local-endpoint-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/local-endpoint-entrypoint.sh"]
