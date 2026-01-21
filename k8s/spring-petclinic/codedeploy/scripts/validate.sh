#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG=/home/ubuntu/.kube/config

kubectl get ingress petclinic
kubectl get pods -l app=petclinic
