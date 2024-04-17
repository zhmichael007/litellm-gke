#!/bin/bash
PROJECT_ID=<YOUR PROJECT ID>
CLUSTER_NAME=litellm-proxy
REGION=us-central1
MASTER_ZONE=us-central1-a
ZONE=(us-central1-a us-central1-b us-central1-c)
NETWORK=default
MAX_NODES=5
MACHINE_TYPE=e2-custom-2-4096
DISK_SIZE="50" 
KSA_ROLE=roles/aiplatform.user
KSA_NAME=k8s-sa 
APP_SA_NAME=litellm-sa

gcloud config set project $PROJECT_ID

echo "start GKE node pool provisioning, cluster name: " $CLUSTER_NAME

#create a cluster with a default node pool
gcloud beta container clusters create $CLUSTER_NAME \
    --zone $MASTER_ZONE \
    --node-locations $ZONE \
    --machine-type $MACHINE_TYPE \
    --workload-pool=$PROJECT_ID.svc.id.goog \
    --addons GcsFuseCsiDriver \
    --num-nodes 1 \
    --autoscaling-profile optimize-utilization \
    --network=$NETWORK

#get the credentials of the cluster
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$MASTER_ZONE

echo "create on demand node pool for zone $zone"
gcloud beta container node-pools create "ondemand-pool" \
    --zone $MASTER_ZONE \
    --cluster=$CLUSTER_NAME \
    --node-locations $ZONE \
    --machine-type=$MACHINE_TYPE \
    --num-nodes 0 \
    --total-min-nodes=0 \
    --total-max-nodes=$MAX_NODES \
    --enable-autoscaling \
    --disk-size $DISK_SIZE \
    --disk-type "pd-ssd" \
    --node-labels=instance-type=ondemand \
    --workload-metadata=GKE_METADATA

echo "create spot node pool for zone $zone"
gcloud beta container node-pools create "spot-pool" \
    --zone $MASTER_ZONE \
    --cluster=$CLUSTER_NAME \
    --node-locations $ZONE \
    --machine-type $MACHINE_TYPE \
    --num-nodes 0 \
    --total-max-nodes=$MAX_NODES \
    --enable-autoscaling \
    --disk-size $DISK_SIZE \
    --disk-type "pd-ssd" \
    --node-labels=instance-type=spot \
    --workload-metadata=GKE_METADATA \
    --spot

#delete default node pool
gcloud container node-pools delete default-pool --zone=$MASTER_ZONE --cluster=$CLUSTER_NAME --quiet

#Set GKE workload identity
#K8s SA
kubectl create serviceaccount $KSA_NAME --namespace default

#App SA
gcloud iam service-accounts create $APP_SA_NAME --project=$PROJECT_ID

#add access to APP SA
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:$APP_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role $KSA_ROLE

#add iam binding
gcloud iam service-accounts add-iam-policy-binding $APP_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[default/$KSA_NAME]"

#add annotation
kubectl annotate serviceaccount $KSA_NAME \
    --namespace default \
    iam.gke.io/gcp-service-account=$APP_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
