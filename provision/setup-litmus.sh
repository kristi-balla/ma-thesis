#!/bin/bash

helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm repo update

# install the portal and mongodb (the db being most important)
helm install portal litmuschaos/litmus --namespace litmus --create-namespace

# the core has the CRDs
helm install core litmuschaos/litmus-core --namespace litmus

# install the agent according to my values
helm install agent litmuschaos/litmus-agent --namespace litmus -f /vagrant/inputs/helm/litmus-agent-values.yml

# install the experiments themselves
helm install k8s-chaos litmuschaos/kubernetes-chaos --namespace litmus

kubectl -n litmus get all
