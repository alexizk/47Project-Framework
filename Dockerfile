# 47Project Framework - runtime container (Linux)
# Builds a minimal image that can run the Nexus shell via PowerShell 7.
# Note: Docker daemon inside a container typically requires privileged mode (DinD) or a mounted host socket.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -o Acquire::Retries=5 && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg apt-transport-https lsb-release \
      git unzip zip && \
    rm -rf /var/lib/apt/lists/*

# Install PowerShell (Microsoft repo)
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/microsoft.list && \
    apt-get update -o Acquire::Retries=5 && \
    apt-get install -y --no-install-recommends powershell && \
    rm -rf /var/lib/apt/lists/*

# Install Docker CLI (optional, for interacting with host docker via mounted socket)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /usr/share/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update -o Acquire::Retries=5 && \
    apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Default: show menu (non-interactive friendly)
ENTRYPOINT ["pwsh","-NoLogo","-NoProfile","-File","./Framework/47Project.Framework.ps1"]
CMD ["-Menu"]
