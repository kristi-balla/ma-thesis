#!/bin/bash

# install monitoring stack
kubectl create ns monitoring
kubectl -n monitoring apply -f /vagrant/configs/grafana-dashboards.yml
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack -n monitoring -f /vagrant/inputs/helm/loki-values.yml
helm install fluent-bit fluent/fluent-bit -n monitoring -f /vagrant/inputs/helm/fluent-bit-values.yml
sleep 30
helm install kps -n monitoring --create-namespace oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack -f /vagrant/inputs/helm/kps-values.yml

# idfk why, but grafana complains only 1 datasource per organization can be marked as default
# and idk which one how it's managing to set multiple as default
# kubectl -n monitoring rollout restart deploy/kps-grafana

kubectl -n monitoring apply -f /vagrant/configs/service-monitors.yml
