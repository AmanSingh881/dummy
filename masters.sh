#!/bin/bash

# --------------------------
# CONFIGURATION
# --------------------------

AWS_REGION="us-east-1"

LOAD_BALANCER_DNS=$(aws ssm get-parameter \
  --name "/myapp/nlb_dns" \
  --with-decryption \
  --region ${AWS_REGION} \
  --query "Parameter.Value" \
  --output text)

# --------------------------
# STEP 1: Fetch values from AWS SSM Parameter Store
# --------------------------
echo "[INFO] Fetching join parameters from AWS SSM..."

JOIN_TOKEN=$(aws ssm get-parameter \
  --name "/k8s/join-token" \
  --with-decryption \
  --region ${AWS_REGION} \
  --query "Parameter.Value" \
  --output text)

CA_CERT_HASH=$(aws ssm get-parameter \
  --name "/k8s/ca-cert-hash" \
  --with-decryption \
  --region ${AWS_REGION} \
  --query "Parameter.Value" \
  --output text)

CERT_KEY=$(aws ssm get-parameter \
  --name "/k8s/certificate-key" \
  --with-decryption \
  --region ${AWS_REGION} \
  --query "Parameter.Value" \
  --output text)

# --------------------------
# STEP 2: Run kubeadm join for control-plane
# --------------------------
echo "[INFO] Joining this node as a control-plane node..."

sudo kubeadm join ${LOAD_BALANCER_DNS}:6443 \
  --token ${JOIN_TOKEN} \
  --discovery-token-ca-cert-hash ${CA_CERT_HASH} \
  --control-plane \
  --certificate-key ${CERT_KEY}

sudo mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "[INFO] Node successfully joined as control-plane!"

# sudo apt-get update
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/tigera-operator.yaml
# sudo apt-get update
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/custom-resources.yaml

