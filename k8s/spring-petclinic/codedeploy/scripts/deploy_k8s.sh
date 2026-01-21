#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG=/home/ubuntu/.kube/config

cd /opt/codedeploy/petclinic

kubectl apply -f k8s/petclinic.yml
kubectl rollout status deploy/petclinic --timeout=240s
kubectl get pods -l app=petclinic -o wide
