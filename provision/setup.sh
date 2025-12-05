#!/bin/bash

# start cluster with flannel CNI bc it has simple packet forwarding features
minikube start --memory=8.5G --wait=all

# install open5gs
helm install open5gs oci://registry-1.docker.io/gradiantcharts/open5gs -f /vagrant/inputs/helm/open5gc-values.yml
sleep 30

# install ueransim to simulate a ground station to connect to 5g core
helm install useranism-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb -f /vagrant/inputs/helm/gnb-ues-values.yml
sleep 30

# install monitoring stack
kubectl create ns monitoring
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack -n monitoring -f /vagrant/inputs/helm/loki-values.yml
helm install fluent-bit fluent/fluent-bit -n monitoring -f /vagrant/inputs/helm/fluent-bit-values.yml
helm install kps -n monitoring --create-namespace oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack -f /vagrant/inputs/helm/grafana-values.yml
sleep 30
