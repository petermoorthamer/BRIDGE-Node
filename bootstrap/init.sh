#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Configurable parameters
# -----------------------------
API_URL="https://portal.bridge.central/api/v1/register"
OIDC_TOKEN_URL="https://keycloak.bridge.central/realms/BRIDGE/protocol/openid-connect/token"
CLIENT_ID="my-client-id"
CLIENT_SECRET="my-client-secret"
SSH_KEY_PATH="$HOME/.ssh/bridge_github_key"
CLONE_DIR="/$HOME/bridge_ansible_playbook"
NODENAME="$HOSTNAME"

# -----------------------------
# Ensure dependencies
# -----------------------------

# Check if python3 is installed
echo "[INFO] Installing dependencies..."
if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] Python3 is required but not installed."
  exit 1
fi

# Install pip if needed
if ! command -v pip3 >/dev/null 2>&1; then
  echo "[INFO] Installing pip..."
  sudo apt-get update && sudo apt-get install -y python3-pip
fi

# Install python dependencies
if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "[INFO] Installing Ansible..."
  pip3 install --user --upgrade ansible requests
else
  pip3 install --user --upgrade requests
fi

# -----------------------------
# Generate SSH key pair
# -----------------------------
echo "[INFO] Generating SSH key..."
mkdir -p "$(dirname "$SSH_KEY_PATH")"
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t rsa -b 4096 -C "bridge-$NODENAME" -f "$SSH_KEY_PATH" -N ""
fi
PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

# -----------------------------
# Register & fetch repo URL
# -----------------------------
echo "[INFO] Registering with BRIDGE registration API using OIDC client credentials..."
REPO_URL=$(python3 register.py "$API_URL" "$PUBLIC_KEY" "$OIDC_TOKEN_URL" "$CLIENT_ID" "$CLIENT_SECRET")
echo "[INFO] Received repo URL: $REPO_URL"

# -----------------------------
# Clone GitHub repo
# -----------------------------
echo "[INFO] Cloning Ansible playbook..."
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY_PATH"

rm -rf "$CLONE_DIR"
git clone "$REPO_URL" "$CLONE_DIR"

# -----------------------------
# Run Ansible playbook
# -----------------------------
echo "[INFO] Running Ansible playbook..."
cd "$CLONE_DIR"

# Assumes repo has site.yml or main.yml as entrypoint
if [ -f "site.yml" ]; then
  ansible-playbook site.yml
elif [ -f "main.yml" ]; then
  ansible-playbook main.yml
else
  echo "[ERROR] Could not find site.yml or main.yml in playbook repo."
  exit 1
fi

echo "[INFO] Done."