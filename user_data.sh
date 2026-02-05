#!/bin/bash
set -euxo pipefail

# Update system packages
dnf update -y

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group (so they can run docker without sudo)
usermod -aG docker ec2-user

# Install kubectl
KUBECTL_VERSION="v1.31.0"  # Change to desired version or use "stable"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

# Verify checksum
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Install kubectl
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Clean up
rm -f kubectl kubectl.sha256

# Verify installations
docker --version
kubectl version --client

echo "Docker and kubectl installation complete" | tee /var/log/user-data-complete.log
