#!/bin/bash

cd /home/vagrant/
git clone https://github.com/kristi-balla/testbed-automator.git
cd testbed-automator/
./install.sh

sleep 30

cd /home/vagrant/
git clone https://github.com/kristi-balla/open5gs-k8s.git
cd open5gs-k8s/
./deploy-all.sh

cd /home/vagrant/
