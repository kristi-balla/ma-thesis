# Chaos Experiments

This is a non-exhaustive summary of the ideas I have for chaos experiments.
I tried to cover a large area of experiments, ranging from basic misconfigurations and generic Kubernetes failures, to 5G specific errors.

## Stable State

This is defined as the state with a healthy 5G control plane and 2 registered UEs with a functioning internet connection.

## Misconfigurations

Each NF has its own `ConfigMap` that is applied.
The approach to be followed is patching the config with the required value and then restarting the corresponding deployment.

One misconfiguration affecting all NFs is patching the `sbi` config such that the deployment no longer reaches the SCP, or is no longer reachable itself.

### AMF

The AMF pins down the IP of the ground node it talks to via NGAP. Changing that could lead to UEs not connecting or other symptoms.

The AMF specifies a GUAMI.
I wonder what happens when the deployment scales and there are suddenly multiple AMFs with the same GUAMI.

The AMF specifies the PLMN it connects to.
That also includes the slices.
Setting it to connect to a non-existent slice or wrong config parameters ough to do the trick.

The AMF defines the ciphers it uses in a specific order of precedence in its security configuration.
A mismatch between those and the ones requested by the UE could cause the UE to get rejected.

### NRF

In its `serving` section, the NRF defines which PLMN it is serving.
Patching this might cause wider failures in the other services that expect to connect to the NRF.

This function also has an env-var hard-coded to the mongo database.
This enables testing for cases when the connection link is faulty.

### NSSF

In its `nssf.client.nsi` field, the NSSF defines the network slices.
A mismatch between this and those that other functions expect could have silence cluster communication.

### PCF

This function also has a connection mongodb, but that is in the configuration file.
Nonetheless, it enables testing for cases when the connection link is faulty.

### SCP

The SCP contains a `no_sepp` field.
Since this is a local setting, it is set to `true`.
However, patching it to false might make the NFs react accordingly and produce confusing outputs.

### SMF

Misconfigurations in the `pfcp.client` or `pfcp.server` sections could cause packets to be sent to the wrong interfaces.
Since those are hard-coded, they can be changed.

### UPF

It hard-codes some interfaces and session config.

## Kubernetes

LitmusChaos provides some pre-defines experiments.
While some can already be used in the previous section, some are best put in this category.

### Hoggers

There are some experiments that hog resources (most notably CPU and memory, but also disk space), from pods or nodes.
I would like to run them to see how the runtime and the NFs themselves handle this and what kind of noise is created.
That might lead to logs I can input into my analysis.

### Networking

There are experiments to block DNS resolution of hostnames or spoof DNS requests.
Both could be used to fascilitate a state of confusion in the cluster, despite everything being configured "correctly".

In addition, packet corruption or duplication could be deployed.
Networks can also introduce latency or blatantly drop packets.
Also, a network policy could be in place that prohibits that communication between pods.
These examples could generate confusing logs for the LLM to parse.

## More Advanced Cases

### Slices

When a new slice gets introduced, but not all NFs are registered (yet), it would be interesting to see how UEs get registered. Also, it could be that the NFs of the new slice start starving out the NFs in other slices, if they're all running on the same node.

In addition, what happens with UEs that can't be placed on any slice? Or when the UE config changes and their old slice can no longer serve them? These are native experimentation ideas.
