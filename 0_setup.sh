#!/bin/bash
set -ex

k8s_master="master-k8s"
k8s_worker="k8s-worker"
workers_total=2

function create-cluster() {
    multipass launch --name $k8s_master --cpus 2 --memory 2048M --disk 5G
    for (( w=1; w<=$workers_total; w++ )) 
    do
        multipass launch --name $k8s_worker-$w --cpus 2 --memory 2048M --disk 5G
    done
}

function deploy-k3s() {
    multipass exec $k8s_master -- bash -c "curl -sfL https://get.k3s.io | sh -"
    K3S_MASTER_TOKEN=$(multipass exec $k8s_master sudo cat /var/lib/rancher/k3s/server/node-token)
    K3S_MASTER_IP=$(multipass info $k8s_master | grep IPv4 | awk '{print $2}')
    for (( w=1; w<=$workers_total; w++ )) 
    do
        multipass exec $k8s_worker-$w -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$K3S_MASTER_IP:6443\" K3S_TOKEN=\"$K3S_MASTER_TOKEN\" sh -"
    done
    
    #https://copyprogramming.com/howto/error-kubernetes-cluster-unreachable-get-http-localhost-8080-version-timeout-32s-dial-tcp-127-0-0-1-8080-connect-connection-refused
    multipass exec $k8s_master -- bash -c "mkdir -p ~/.kube"
    multipass exec $k8s_master -- bash -c "kubectl config view --raw > ~/.kube/config"
    multipass exec $k8s_master -- bash -c "sudo apt  install jq -y"
}

function clean-up() {
    multipass stop $k8s_master
    multipass delete $k8s_master
    for (( w=1; w<=$workers_total; w++ )) 
    do
        multipass stop $k8s_worker-$w
        multipass delete $k8s_worker-$w
    done
    multipass purge
    echo "clean"
}

create-cluster
deploy-k3s
# clean-up

