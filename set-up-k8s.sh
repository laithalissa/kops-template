#!/bin/bash
#
# I've hacked this together from my loose script fragments, I have never executed this,
# so process with caution :D
set -xe

. ./config.sh

create_iam_entities() {
    create iam group and user for kops
    aws iam create-group --group-name ${KOPS_IAM_GROUP}
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name ${KOPS_IAM_GROUP}
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name ${KOPS_IAM_GROUP}
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name ${KOPS_IAM_GROUP}
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name ${KOPS_IAM_GROUP}
    aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name ${KOPS_IAM_GROUP}
    aws iam create-user --user-name ${KOPS_IAM_USER}
    aws iam add-user-to-group --user-name ${KOPS_IAM_USER} --group-name ${KOPS_IAM_GROUP}
    aws iam create-access-key --user-name ${KOPS_IAM_USER}
}

create_s3_state_store() {
    aws s3 mb s3://${KOPS_BUCKET_NAME} --region eu-west-2
    aws s3api put-bucket-versioning --bucket ${KOPS_BUCKET_NAME} --versioning-configuration Status=Enabled
}

generate_ssh_keys() {
    mkdir -p ./keys/
    ssh-keygen -f ./keys/id_rsa
    ssh-keygen -b 2048 -t rsa -f ./keys/id_rsa -q -N ""
}

install_helm() {
    helm init
    helm version
    #    The above might fail due to a permission error, the following might fix it.
    #    kubectl create serviceaccount --namespace kube-system tiller
    #    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    #    kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
}

# create_iam_entities
# create_s3_state_store

if [ ! -f ./keys/id_rsa.pub ]; then
    generate_ssh_keys
else
    echo "Existing ssh keys detected, not generating new ones..."
fi

local simple_zones='eu-west-1a'
local ha_zones='eu-west-1a,eu-west-1b,eu-west-1c'
ZONES=$ha_zones

kops-1.12.2 create cluster \
  --zones $ZONES \
  --master-zones $ZONES \
  --node-count 1 \
  --node-size m5.xlarge \
  --vpc ${VPC_ID} \
  --topology private \
  --networking flannel \
  --ssh-public-key ./keys/id_rsa.pub ${CLUSTER_NAME}

mkdir -p ./specs
kops get cluster --name $CLUSTER_NAME -o yaml > ./specs/cluster.yaml
kops get ig --name $CLUSTER_NAME -o yaml > ./specs/nodes.yaml

read -p "Make changes to ./specs/cluster.yaml and ./specs/nodes.yaml, then press \"C\" to continue" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Cc]$ ]]
then
    echo "Aborted by user"
    exit 1
fi

kops replace -f ./specs/nodes.yaml --name ${CLUSTER_NAME}
kops replace -f ./specs/cluster.yaml --name ${CLUSTER_NAME}

kops update cluster --name ${CLUSTER_NAME}

read -p "Do you wish to proceed with creating the cluster? [Y]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Aborted by user"
    exit 1
fi
kops update cluster --name ${CLUSTER_NAME} --yes

echo "Creating cluster. You can spectate by executing:"
echo "watch 'kubectl get nodes'"
