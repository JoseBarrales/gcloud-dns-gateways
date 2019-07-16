#!/bin/bash
# Generates dns records for services declared on istio

DNS_ZONE=$1
DNS_ZONE_NAME=$(echo $DNS_ZONE | sed 's/\./-/g')
ISTIO_HOST="istio.$DNS_ZONE"
PROJECT=$2
K8S_PROJECT=$3
K8S_ZONE=$4
K8S_CLUSTER_NAME=$5

gcloud container clusters get-credentials $K8S_CLUSTER_NAME --zone $K8S_ZONE --project $K8S_PROJECT
gcloud config set project $PROJECT

kubectl get ns -o jsonpath='{.items[*].metadata.name}' | sed 's/ /\n/g' | xargs -n1 kubectl get gateway -o jsonpath='{.items[*].spec.servers[*].hosts[*]} ' -n | sed 's/ /. \n/g' | sed '/^$/d' | sed '/\*/d' | sed  "/$DNS_ZONE/!d" | sed '/^$/d'  > k8
gcloud dns record-sets list --zone="$DNS_ZONE_NAME" | grep -oP '[^(a-z)]*\K[^ ]*' | sort -t: -u -k1,1 | sed  "/$DNS_ZONE/!d" > gcp

forInsert=$(awk 'FNR==NR{a[$1];next}!($1 in a){print}' gcp k8 | sed 's/ /\n/g' )
forUpdate=$(awk 'FNR==NR{a[$1];next}($1 in a){print}' gcp k8 | sed 's/ /\n/g')

for host in $forInsert
do
        echo $host
        gcloud dns --project=$PROJECT record-sets transaction start --zone=$DNS_ZONE_NAME
        gcloud dns --project=$PROJECT record-sets transaction add "istio.$DNS_ZONE." --name="$host" --ttl=300 --type=CNAME --zone=$DNS_ZONE_NAME
        gcloud dns --project=$PROJECT record-sets transaction execute --zone=$DNS_ZONE_NAME
done

rm gcp k8