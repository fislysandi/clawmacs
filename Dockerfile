FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    sbcl \
    nodejs \
    npm \
    libssl3 \
    libssl-dev \
    libcurl4 \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10.28.2 --activate

WORKDIR /opt/clawmacs

COPY . /opt/clawmacs

# Install Quicklisp for root user (container runtime user)
RUN sbcl --script /opt/clawmacs/quicklisp-install-proxy.lisp /tmp/quicklisp.lisp && \
    rm -f /tmp/quicklisp.lisp

# Ensure ASDF can find project systems inside this checkout
RUN mkdir -p /root/.config/common-lisp/source-registry.conf.d && \
    printf '(:tree "/opt/clawmacs/projects/")\n' > /root/.config/common-lisp/source-registry.conf.d/clawmacs.conf

# Install Node helper dependencies for Codex OAuth bridge
RUN pnpm --dir /opt/clawmacs/projects/cl-llm/node install

EXPOSE 18789

CMD ["bash", "/opt/clawmacs/projects/clambda-core/bin/clawmacs-server", "--port", "18789", "--address", "0.0.0.0", "--no-swank", "--no-channels"]
