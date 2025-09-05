
#!/bin/bash


# --------------------------
# CONFIGURATION
# --------------------------
# LOAD_BALANCER_DNS="kube-3a7860249db68602.elb.us-east-1.amazonaws.com"
POD_NETWORK_CIDR="192.168.0.0/16"
AWS_REGION="us-east-1"

LOAD_BALANCER_DNS=$(aws ssm get-parameter \
  --name "/myapp/nlb_dns" \
  --with-decryption \
  --region ${AWS_REGION} \
  --query "Parameter.Value" \
  --output text)

# --------------------------
# STEP 1: Initialize cluster
# --------------------------
# echo "[INFO] Initializing Kubernetes control plane..."
sudo kubeadm init \
  --control-plane-endpoint "${LOAD_BALANCER_DNS}:6443" \
  --upload-certs \
  --pod-network-cidr="${POD_NETWORK_CIDR}"

# --------------------------
# STEP 2: Setup kubeconfig for kubectl
# --------------------------
echo "[INFO] Setting up kubeconfig for kubectl..."
sudo mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# --------------------------
# STEP 3: Create non-expiring join token
# --------------------------
echo "[INFO] Creating non-expiring join token..."
JOIN_TOKEN=$(sudo kubeadm token create --ttl 0)

# --------------------------
# STEP 4: Extract discovery token CA cert hash
# --------------------------
echo "[INFO] Extracting discovery-token-ca-cert-hash..."
CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex \
  | awk '{print $2}')

# --------------------------
# STEP 5: Upload control-plane certificates and extract certificate key
# --------------------------
echo "[INFO] Uploading control-plane certificates..."
CERT_KEY=$(sudo kubeadm init phase upload-certs --upload-certs | tail -n 1)

# --------------------------
# STEP 6: Store values in AWS SSM Parameter Store
# --------------------------
echo "[INFO] Storing parameters in AWS SSM Parameter Store..."

aws ssm put-parameter \
  --name "/k8s/join-token" \
  --type "SecureString" \
  --value "${JOIN_TOKEN}" \
  --overwrite \
  --region ${AWS_REGION}

aws ssm put-parameter \
  --name "/k8s/ca-cert-hash" \
  --type "SecureString" \
  --value "sha256:${CA_CERT_HASH}" \
  --overwrite \
  --region ${AWS_REGION}

aws ssm put-parameter \
  --name "/k8s/certificate-key" \
  --type "SecureString" \
  --value "${CERT_KEY}" \
  --overwrite \
  --region ${AWS_REGION}

# --------------------------
# STEP 7: Print join commands
# --------------------------
echo "[INFO] Kubernetes cluster initialized successfully!"
echo ""
echo "👉 Use the following join commands:"
echo ""
echo "Control-plane node:"
echo "kubeadm join ${LOAD_BALANCER_DNS}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash sha256:${CA_CERT_HASH} --control-plane --certificate-key ${CERT_KEY}"
echo ""
echo "Worker node:"
echo "kubeadm join ${LOAD_BALANCER_DNS}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash sha256:${CA_CERT_HASH}"

sudo apt-get update
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/tigera-operator.yaml
sudo apt-get update
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/custom-resources.yaml
