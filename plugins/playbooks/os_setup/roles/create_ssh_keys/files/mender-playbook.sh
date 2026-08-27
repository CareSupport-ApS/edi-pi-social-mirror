#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

GITOPS_USER_NAME="gitops"
GITOPS_USER_GROUP_NAME="gitops"
GITOPS_USER="sudo -u ${GITOPS_USER_NAME}"
WORKDIR="/home/${GITOPS_USER_NAME}/playbook"

PLAYBOOK_URL="git@github.com:CareSupport-ApS/social-mirror.git"
PLAYBOOK_VERSION="main"
PLAYBOOK_NEEDS_REBOOT="true"

LOCK_FILE="/var/lib/mender-playbook.lock"

if [ -f "${LOCK_FILE}" ]; then
    echo "[INFO] Mender playbook has already been executed. Exiting..."
    exit 0
fi

mkdir -p /var/lib
touch "${LOCK_FILE}"

echo "[INFO] Script execution started."

# 🖥️ Initialize Display & Progress Bar
echo "[INFO] Initializing display..."
/usr/local/bin/init_display.sh || echo "[WARNING] Display init failed"

echo "[INFO] Starting progress bar..."
export DISPLAY=:0
nohup python3 /usr/local/bin/progress_bar.py > /dev/null 2>&1 &
echo $! > /tmp/progress_bar.pid

# Function to update progress
update_progress() {
    echo "$1|$2" > /tmp/ansible_progress
}

update_progress 5 "Waiting for clock sync..."

print_error() {
    local MESSAGE="${1}"
    >&2 echo -e "${0}: [ERROR] ${MESSAGE}"
}

for i in {1..60}; do
    sync_status="$(timedatectl show --property=NTPSynchronized --value)"
    if [[ $sync_status =~ "yes" ]]; then
        echo "[INFO] System clock synchronized."
        break
    else
        echo "[WARNING] Waiting for system clock synchronization..."
    fi
    sleep 10
done

update_progress 10 "Updating package list..."
echo "[INFO] Updating package list."
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null
echo "[INFO] Installing git."
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install git > /dev/null

update_progress 15 "Installing Ansible..."
echo "[INFO] Installing required Ansible collections."
${GITOPS_USER} ansible-galaxy collection install community.general:11.4.1 ansible.posix:1.5.4 --force

echo "[INFO] Creating working directory: ${WORKDIR}"
mkdir -p "${WORKDIR}"
chown -R ${GITOPS_USER_NAME}:${GITOPS_USER_GROUP_NAME} "${WORKDIR}"
chmod -R 755 "${WORKDIR}"
cd "${WORKDIR}"

if [ -d ".git" ]; then
    echo "[WARNING] Existing Git data found. Clearing directory."
    ${GITOPS_USER} rm -rf .git
fi
if [ "$(ls -A)" ]; then
    echo "[WARNING] Directory is not empty. Clearing non-Git files."
    ${GITOPS_USER} find . -mindepth 1 -not -name ".git" -exec rm -rf {} +
fi

update_progress 20 "Cloning repository..."
echo "[INFO] Cloning repository ${PLAYBOOK_URL} (branch: ${PLAYBOOK_VERSION})"
echo "[INFO] Debugging SSH connection and Git clone..."
GIT_SSH_COMMAND="ssh -vvv"
GIT_CURL_VERBOSE=1 GIT_TRACE=1
if ! ${GITOPS_USER} GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -vvv" GIT_CURL_VERBOSE=1 GIT_TRACE=1 git clone --no-checkout --filter=blob:none --sparse -c advice.detachedHead=false --branch "${PLAYBOOK_VERSION}" --depth 1 "${PLAYBOOK_URL}" .; then
    print_error "Failed to clone repository. Check SSH access and permissions."
    update_progress 0 "Clone Failed!"
    exit 1
fi

echo "[INFO] Configuring sparse-checkout for directories: hardware-ansible, hardware-agent"
${GITOPS_USER} git sparse-checkout set hardware-ansible hardware-agent
${GITOPS_USER} git checkout

update_progress 30 "Running Ansible Playbook..."
echo "[INFO] Running Ansible playbook from hardware-ansible directory."
cd "${WORKDIR}/hardware-ansible"
${GITOPS_USER} ansible-playbook --connection=local --inventory 127.0.0.1, playbook.yml 1>&2

echo "[INFO] Playbook execution finished."

# Stop progress bar if it's still running (Ansible might have stopped it or started a new one)
if [ -f /tmp/progress_bar.pid ]; then
  kill $(cat /tmp/progress_bar.pid) || true
  rm /tmp/progress_bar.pid
fi

if [ "${PLAYBOOK_NEEDS_REBOOT}" == "true" ]; then
    echo "[INFO] Rebooting system as required by playbook."
    reboot
fi

echo "[INFO] Script execution completed."
