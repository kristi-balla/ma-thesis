# Understanding Cluster Deployment

This document is to break down all dependencies and configuration the testbed automator undertakes to configure the cluster. 
Every config, dependency, version, and tool will be noted down here.

## Dependencies

### APT

- vim
- tmux
- git
- curl
- iproute2
- iputils-ping
- iperf3
- tcpdump
- python3-pip
- jq
- openvswitch-switch

### Deb822

<!-- This is essentially a normal docker installation -->
- docker-ce
- docker-ce-cli
- containerd.io
- docker-buildx-plugin
- docker-compose-plugin

<!-- TODO: investigate whether this works on their latest versions!
They only tried it with v1.28, but that is old! -->
- kubectl
- kubelet
- kubeadm
- helm

### Helm Charts

- openebs (make sure to make its storageclass the default one!)

## Testbed Setup

### Nodes

This is the setup for nodes.
Unless explicitly mentioned, this is for master as well as worker nodes.
Make sure to install the [dependencies](#dependencies) in each node first!

Then, make sure to configure restarts:

```bash
sudo mkdir -p /etc/needrestart
printf '$nrconf{restart} = "a";\n' | sudo tee /etc/needrestart/needrestart.conf > /dev/null
```

You also need to disable some basic features such as swap or firewalls:

```bash
sudo swapoff -a
sudo sed -i '/swap/ s/^/#/' /etc/fstab
sudo ufw disable
```

Then, you need to enable some networking configuration:

```bash
echo "Setting up Kubernetes networking ..."
  # Load required kernel modules
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

  sudo modprobe overlay
  sudo modprobe br_netfilter

  # Configure sysctl parameters for Kubernetes
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

  # Apply sysctl parameters without reboot
  sudo sysctl --system > /dev/null
```

You also want to configure containerd to use the systemd driver.
This has nothing to do with it being more modern than the cgroupfs driver.
Rather, kubeadm views the kubelet processes as systemd units and thus manages them as such.
That needs to be reflected in the containerd config as well:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee -a /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable containerd
sudo systemctl restart containerd
```

This is a kubeadm cluster with systemd as the cgroup driver.
Thus, we need to configure that in the **master node**:

```yml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: "10.244.0.0/16" # --pod-network-cidr
```

Then, we actually create the cluster, setup kubectl for rootless usage and remove the NoSchedule taint from the master node:

```bash
sudo kubeadm init --config kubeadm-config.yaml

# Setup kubectl without sudo
mkdir -p ${HOME}/.kube
sudo cp /etc/kubernetes/admin.conf ${HOME}/.kube/config
sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

# Wait for cluster readiness

# Remove NoSchedule taint from all nodes
# s.t. normal workloads can also be scheduled on the control plane
echo "Allowing scheduling pods on master node ..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

After the cluster is up and running, you want to configure the CNIs:

- **flannel** as the primary CNI.
- **multus** as meta CNI to allow multi-homed pods.
- **openvswitch** as the secondary CNI.

OpenVSwitch is configured like so:

```bash
sudo ovs-vsctl --may-exist add-br n2br
sudo ovs-vsctl --may-exist add-br n3br
sudo ovs-vsctl --may-exist add-br n4br

# You'll have to apply necessary CRDs
```

Also, you'll need to apply some network addons config:

```yaml
apiVersion: networkaddonsoperator.network.kubevirt.io/v1
kind: NetworkAddonsConfig
metadata:
  name: cluster
spec:
  ovs: {}
```

You also want to increase the max of these variables bc the old limits will be trampled over:

```bash
line1="fs.inotify.max_user_watches=524288"
line2="fs.inotify.max_user_instances=512"

# Check if the lines already exist in /etc/sysctl.conf, and add them if they don't
grep -qxF "$line1" /etc/sysctl.conf || echo "$line1" | sudo tee -a /etc/sysctl.conf
grep -qxF "$line2" /etc/sysctl.conf || echo "$line2" | sudo tee -a /etc/sysctl.conf

# Reload sysctl settings
sudo sysctl -p
```

## Open5Gs Setup

Everything will take place in the `open5gs` namespace. Create it at the beginning!

### MongoDB

They apply this config. Figure out if you can do the same with the corresponding helm chart alone:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  labels:
    app.kubernetes.io/name: mongodb
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: mongodb
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:5.0
          args:
            - "--bind_ip_all"
          env:
            - name: MONGO_INITDB_DATABASE
              value: "admin"
          ports:
            - name: mongodb
              containerPort: 27017
          livenessProbe:
            exec:
              command:
                - mongo
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 10
            failureThreshold: 3
          readinessProbe:
            exec:
              command:
                - mongo
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 10
            failureThreshold: 3
          volumeMounts:
            - name: datadir
              mountPath: /data/db
  volumeClaimTemplates:
    - metadata:
        name: datadir
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "6Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  labels:
    app.kubernetes.io/name: mongodb
spec:
  # TODO: consider setting clusterIP: none to fascilitate communication to sts
  type: ClusterIP
  ports:
    - name: mongodb
      port: 27017
      targetPort: mongodb
  selector:
    app.kubernetes.io/name: mongodb
```

Later on, they also add an admin account. That can be done via env vars tho! Check `MONGODB_INIT_USERNAME` (or similar) and password. You might also want to get a look into the init-db.js script from your IDP!

Also, they run the following:

```bash
python3 mongo-tools/generate-data.py
python3 mongo-tools/add-subscribers.py
python3 mongo-tools/check-subscribers.py
```

This is all done in their venv. I hate venv's. I will wrap this in a `Job` and run those steps in a custom container. Let that talk to the db and populate it! No unnecessary shit will go down on my host!

### Open5Gs

This will install the entire `kustomization` project, including the slices. No webui is included by default, so you want to add it in here (toggle in helm chart)! This is the part I wanted to make a helm chart out of. Pasting it all in here is too much, so please check in that dir!

### Ueransim

This will install the corresponding `kustomization` project. Check if you can also package this in the same helm chart as before!

In the end, there is a ping test in which they exec into all ueransim pods and test connectivity. This ought to be the end of the setup!
