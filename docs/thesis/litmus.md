# LitmusChaos

A summary of notes from my understanding of litmus chaos: its installation and usage.

## Installation

You aren't interested in ClickOps and setting up a guide consisting of images only showing a user where to click.
Also, that severly hinders reproducability.
Thus, I need to write down the workflows as code and figure out a way to apply them.
That brings me to the OS helm charts for litmus.
Under [litmus-helm](https://github.com/litmuschaos/litmus-helm/tree/master/charts), you will find some charts.
The first and foremost important is [litmus](https://github.com/litmuschaos/litmus-helm/tree/master/charts/litmus).
The only reason I have it here is due to its subchart with mongodb.
<!-- TODO: investigate the feasibility of this extra chart here! You wanted to check merging this with open5gs anyway! -->
Then, you want [litmus-core](https://github.com/litmuschaos/litmus-helm/tree/master/charts/litmus-core).
That one will install three crucial CRDs: the experiments, engines and results.
Lastly, you want the [litmus-agent](https://github.com/litmuschaos/litmus-helm/tree/master/charts/litmus-agent).
Comparred to the previous two, follow [litmus-agent-values](../../inputs/helm/litmus-agent-values.yml) to set the proper values for a standalone installation.
Without this, it will rely on the UI and always need an environment and project ID on which to install the chaos agent infrastructure.
<!-- TODO: without the core, you might consider dropping the links to the frontend services -->
Optionally, you can install [kubernetes-chaos](https://github.com/litmuschaos/litmus-helm/tree/master/charts/kubernetes-chaos).
It contains all the available chaos experiments.
You could also have a look through the other cloud-provider specific experiments.
I haven't considered them here due to the ambiguity surrouding them and my topic.
However, a quick glimpse suggests there are interesting experiments there as well!

## Run

After installation, you might want to run your own experiment.
If you create it via the UI and export the resulting Argo Workflow, you will hit a wall of text.
Some steps in there are also useless from my perspective: 

- one defines the `ChaosExperiment`, which already exists in my cluster,
- another deletes the `ChaosEngine`, independent of its `jobCleanUpPolicy`

Thus, I decided to write down my own `ChaosEngine` and apply it.
You can see a simplistic version in [`my-chaos-engine.yml`](../../inputs/services/my-chaos-engine.yml).
After applying that engine, you will notice a job getting spawned, your target pod getting killed and a result being generated.
This is a typical chaos run from my understanding.

## Extracting the Data

<!-- TODO: you still need to figure out how to extract the logs from loki -->
