#!/bin/bash

yellow='\e[1;33m' #Bold
green='\e[92m'  #အစိမ်းရောင်
none='\e[0m'    #အရောင်မရှိ
plain='\033[0m'

#if [[ -n $1 ]] && [[ $2 == e2-* ]] && [[ -n $3 ]] && [[ -n $4 ]] && [[ -n $5 ]] && [[ -n $6 ]] && [[ -n $7 ]] && [[ $(($(date +%s) - $7)) -lt 120 ]] && [[ $(($(date +%s) - $7)) -ge 0 ]]; then

#echo -e "${yellow}Creating instance ...${plain}"
#instance=$(gcloud compute instances create $1 --project=$5 --zone=$4 --machine-type=$2 --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=$6-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --tags=http-server --create-disk=auto-delete=yes,boot=yes,device-name=persistent-disk-0,image=projects/debian-cloud/global/images/debian-10-buster-v20230912,mode=rw,size=10,type=projects/$5/zones/$4/diskTypes/pd-standard --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ec-src=vm_add-gcloud --reservation-affinity=any)
#echo -e "${green}Instance created.${plain}"

#echo -e "${yellow}Creating instance ...${plain}"
#instance=$(gcloud beta container clusters create "$1" --zone "$3" --no-enable-basic-auth --cluster-version "1.27.3-gke.100" --release-channel "regular" --machine-type "$2" --image-type "UBUNTU_CONTAINERD" --disk-type "pd-balanced" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "1" --enable-ip-alias --network "global/networks/default" --subnetwork "regions/$4/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --security-posture=disabled --workload-vulnerability-scanning=disabled --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --no-enable-managed-prometheus --node-locations "$3")
#echo -e "${green}Instance created.${plain}"

#echo -e "${yellow}Checking firewall rule ...${plain}"
#if [[ $(gcloud compute firewall-rules list --format='value(allowed)') == *"'IPProtocol': 'all'"* ]]; then
#echo -e "${green}Firewall rule already exist.${plain}"
#else
echo -e "${yellow}Creating firewall rule ...${plain}"
gcloud compute firewall-rules create default-allow-firewall --action=ALLOW
echo -e "${green}Firewall rule created.${plain}"
#fi
