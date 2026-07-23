FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        dosfstools \
        e2fsprogs \
        file \
        git \
        kmod \
        kpartx \
        mount \
        openssl \
        parted \
        procps \
        python3 \
        python3-pip \
        sudo \
        unzip \
        util-linux \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash builder \
    && printf 'builder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder

WORKDIR /work
USER builder

ENV PATH=/home/builder/.local/bin:/home/builder/pmbootstrap:$PATH

CMD ["./scripts/00-run-all.sh"]
