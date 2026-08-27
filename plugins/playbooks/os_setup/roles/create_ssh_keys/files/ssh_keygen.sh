#!/bin/bash

mkdir -p /home/gitops/.ssh /root/.ssh
chmod 700 /home/gitops/.ssh /root/.ssh

if [ ! -f /home/gitops/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f /home/gitops/.ssh/id_ed25519 -N ""
    chown -R gitops:gitops /home/gitops/.ssh
    chmod 600 /home/gitops/.ssh/id_ed25519
fi

if [ ! -f /root/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
    chmod 600 /root/.ssh/id_ed25519
fi

echo "Fetching GitHub SSH keys..."
ssh-keyscan -H github.com >> /home/gitops/.ssh/known_hosts
ssh-keyscan -H github.com >> /root/.ssh/known_hosts
chown gitops:gitops /home/gitops/.ssh/known_hosts
chmod 644 /home/gitops/.ssh/known_hosts /root/.ssh/known_hosts

echo "SSH key setup completed."
