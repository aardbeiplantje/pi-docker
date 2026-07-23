FROM node:26-trixie-slim AS base

LABEL author="aardbeiplantje@gmail.com"
LABEL description="Docker image for pi.dev - AI-powered CLI tool with secure non-root execution environment"
LABEL version="0.1.0"

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
   less \
   git \
   ripgrep \
   procps \
   sudo \
   fzf \
   file \
   zsh \
   man-db \
   unzip \
   gnupg2 \
   gh \
   iptables \
   ipset \
   iproute2 \
   dnsutils \
   aggregate \
   jq \
   nano \
   vim \
   socat \
   ca-certificates \
   curl \
   lsof \
   strace \
   tshark \
   tcpdump \
   openssl \
   bash \
   openssh-client \
   && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://downloads.arduino.cc/arduino-cli/arduino-cli_1.5.0-1_amd64.deb -o /tmp/arduino-cli.deb && dpkg -i /tmp/arduino-cli.deb && rm /tmp/arduino-cli.deb

USER root
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      perl \
      libwww-curl-perl \
      libnet-ssleay-perl \
      lua5.4 \
      make \
      gcc \
      g++ \
      python3 \
      python3-pip \
      python3-pip-whl \
      python3-venv \
      python3-dev \
      python3-minimal \
      python3-requests \
      python3-scapy \
      socat \
      strace \
      tshark \
      tcpdump \
      ltrace \
      openssl \
      openssh-client \
      docker-ce \
      docker-ce-cli \
      docker-ce-rootless-extras \
      docker-compose-plugin \
      docker-buildx-plugin \
      git \
      cmake \
      ninja-build \
      build-essential \
      binutils \
      nasm \
      clang \
      pkg-config \
      glslc \
      vulkan-tools \
      libvulkan-dev \
      spirv-headers \
      sqlite3 \
      xxd \
      gdb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER root

RUN mkdir -p /workspace/.local \
    && rm -rf $HDIR/.local; \
    ln -sfT /workspace/.local $HDIR/.local \
    && chown node:node /workspace/.local

RUN rm -rf /var/tmp; ln -s /tmp /var/tmp
ENV TMPDIR=/pip/tmp
RUN mkdir -p $TMPDIR && chmod +s $TMPDIR
ENV XDG_CACHE_HOME=/pip
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_ROOT_USER_ACTION=ignore

USER root

# cocoindex
RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        ddgs

RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        cocoindex-code

# install torch
RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        --index-url https://repo.amd.com/rocm/whl/gfx1151/ \
        "rocm[libraries,devel]" \
        torch \
        torchvision \
        torchaudio \
        || exit $?
RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        --extra-index-url https://repo.amd.com/rocm/whl/gfx1151/ \
        "jax_rocm7_plugin==0.9.1+rocm7.13.0" \
        "jax_rocm7_pjrt==0.9.1+rocm7.13.0" \
        "triton==3.6.0+rocm7.13.0" \
        tf-keras \
        || exit $?
RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        "jax==0.9.1" \
        "jaxlib==0.9.1" \
        || exit $?
RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        https://rocm.frameworks.amd.com/whl/gfx1151/flash_attn-2.8.3-py3-none-any.whl \
        || exit $?

RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        accelerate \
        pygame \
        sqlalchemy comfy_aimdo blake3 alembic comfy_kitchen torchsde \
        || exit $?

RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    python3 -m pip install --prefer-binary --upgrade \
        huggingface_hub==1.19.0 \
        || exit $?

# Perl
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("JSON")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("Crypt::OpenSSL::RSA")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("Digest::SHA")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("Net::Curl")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("LWP::UserAgent")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("Term::ReadLine::Gnu")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("Data::UUID")'
RUN PERL5LIB="/home/node/perl5/lib/perl5" perl -MCPAN -e 'CPAN::Shell->install("JSON::PP")'

# Set up non-root user
USER node

WORKDIR /home/node
ENV HDIR=/home/node

# pi.dev
ENV PI_CODING_AGENT_DIR=$HDIR/.pi/agent
ENV NPM_CONFIG_PREFIX=$HDIR/.npm-global
ENV PATH=$PATH:$HDIR/.npm-global/bin
ENV BUN_INSTALL=$HDIR/.bun
RUN npm set prefix $HDIR
ARG CACHEBUST=1
RUN echo "pi-llama cachebust: ${CACHEBUST}"
RUN npm install -g npm
RUN npm install -g bun
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent
RUN npm install -g --ignore-scripts @earendil-works/pi-agent-core
RUN npm install -g --ignore-scripts @earendil-works/pi-ai
RUN npm install -g --ignore-scripts @earendil-works/pi-tui
RUN pi install npm:fd
RUN pi install git:github.com/aardbeiplantje/pi-llama@feat/llama-slot-id-env-var
RUN pi install npm:pi-memctx
RUN pi install npm:@0xkobold/pi-codebase-wiki
RUN pi install npm:pi-mcp-extension
RUN pi install git:github.com/aardbeiplantje/pi-subagents@feat/llama-slot-id-env-var
RUN pi install npm:@termdraw/pi
RUN pi install npm:pi-searxng-search
RUN pi install npm:pi-smart-fetch

USER root
COPY --chown=root:root cocoindex_plugins /lib/python/cocoindex_plugins
COPY --chown=root:root cocoindex_plugins/sitecustomize.py /lib/python/sitecustomize.py
ENV PYTHONPATH=/lib/python
RUN python3 /lib/python/cocoindex_plugins/register_providers.py

FROM base AS runtime
USER root

RUN mkdir -p /workspace/.local
USER node
RUN rm -rf $HDIR/.local \
    && ln -sfT /workspace/.local $HDIR/.local \
    && chown node:node /workspace/.local
USER root
RUN rm -rf /tmp/* /tmp/.*.so /workspace/.local
RUN mkdir -p /workspace
RUN mkdir -p /workdir
RUN mkdir -p /opt/rocm
COPY pi.pl /
COPY settings.json $HDIR/.pi/agent/settings.json
COPY mcp.json $HDIR/.pi/agent/mcp.json
COPY APPEND_SYSTEM.md $HDIR/.pi/agent/APPEND_SYSTEM.md
RUN cd $HDIR/.pi/agent && jq < mcp.json && jq < settings.json
COPY skills $HDIR/.pi/agent/
COPY themes $HDIR/.pi/agent/
COPY mcp /mcp
USER root
RUN \
    --mount=target=/pip,type=cache,sharing=locked \
    for r in /mcp/*/requirements.txt; do \
        python3 -m pip install --prefer-binary --upgrade \
            -r $r; \
    done
RUN mkdir -p /coco-db-files && chown node:node /coco-db-files
RUN ln -s /workspace/.cocoindex /home/node/.cocoindex
ENV TMPDIR=/var/tmp
ENTRYPOINT ["/usr/bin/perl", "/pi.pl"]
