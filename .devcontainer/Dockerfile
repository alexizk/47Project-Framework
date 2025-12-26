FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install PowerShell (pwsh), git, and common utilities
RUN apt-get update \
 && apt-get install -y wget apt-transport-https software-properties-common ca-certificates gnupg \
 && wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
 && dpkg -i /tmp/packages-microsoft-prod.deb \
 && apt-get update \
 && apt-get install -y powershell git unzip zip jq \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/packages-microsoft-prod.deb
