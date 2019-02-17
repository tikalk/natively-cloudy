# Setting A Kubernetes cluster on DigitalOcean with Terraform

TL;DR

The following post will show how to spin-up a kuberentes cluster on Digital Ocean in under 10 min providing you have an account an a spare 30-40$ per month, and all this with 31 lines of Terraform code ...

I wouldn't "go production" but it's a great experimant with good value for money (IMHO).

## So What lays here, well...

This setup will have a managed kuberentes control plane which is **100% free** + 2 instances in a kubernetes `node_pool` which is digital oceans way of calling `workers` or `minions`.

These 2 `droplets` (a.k.a instances) are 15$ per month, and if you decide to setup an ingress with a LoadBlancer (probebly should) that would be an extra 10$ ...

**Please note:** As you add more droples or node pool's / storage your costs will rise of course ...

## Prequisites

* `doctl` - digital ocean cli
* A digital ocean project + authentication token
* `terraform` - for provisioning the cluster an worker nodes
* `kubectl` - for managing thr cluster 

## Setting up the cluster

### 1. Configuring `doctl`

* Install `doctl` by folloing the instruction [here](https://github.com/digitalocean/doctl#installing-doctl)
* Once installed `doctl auth init` provide your auth and you should find a `config.yml` undert `$HOME/.config/doctl/config.yml` which is basically the digital ocean token and a bunch of other stuff related to it.

    We will use this file later on.

### 2. Review Terraform code

* In order to keep `terraform` password free, I use the following command to extract the token and populate the `do_config` variable, by setting `TF_VAR_do_token` env var. 
And thus my code is clean and only the operator / system with this token can operate the cluster.

* Terraform's `main.tf`
    
    This module is pretty simple (I didn't bother with the terraform state ATM) ...

    ```js
    variable "do_token" {}
    ```

    This allows us to poplate the var via environment variable with the `TF_VAR_` prefix like so:

    ```sh
    export TF_VAR_do_token=$(cat ${HOME}/.config/doctl/config.yaml | grep access-token | awk  '{print $NF}')
    ```

    Then setup the provider in our case `digitalocean`(+ utlize the do_config var):

    ```js
    provider "digitalocean" {
        token = "${var.do_token}"
    }
    ```

    And finally setting up the cluster is the following block:

    ```js
    resource "digitalocean_kubernetes_cluster" "tikal-cloud" {
    name    = "tikal-do-cloud"
    region  = "lon1"
    version = "1.12.1-do.2"
    tags    = ["tikal-do-cloud"]

    node_pool {
        name       = "standard-pool"
        size       = "s-2vcpu-2gb"
        node_count = 2
    }
    }
    ```

    Now, in order to export a `kubeconfig` file I can use to do the rest of my work outside (or maybe inside with the helm provider - I haven't decided quite yet) I use the following resource:

    ```js
    resource "local_file" "kubeconfig" {
    filename = "./kube_config_cluster.yml"
    content  = "${digitalocean_kubernetes_cluster.tikal-cloud.kube_config.0.raw_config}"
    }
    ```

    So at the end of the execution, you will find your `kubeconfig` in the current working directory under the name `kube_config_cluster.yml`.

    The full module's code:

    ```sh
    variable "do_token" {}

    provider "digitalocean" {
        token = "${var.do_token}"
    }

    resource "digitalocean_kubernetes_cluster" "tikal-cloud" {
    name    = "tikal-cloud"
    region  = "lon1"
    version = "1.12.1-do.2"
    tags    = ["tikal-cloud"]

    node_pool {
        name       = "standard-pool"
        size       = "s-2vcpu-2gb"
        node_count = 2
    }
    }

    provider "kubernetes" {
    host = "${digitalocean_kubernetes_cluster.tikal-cloud.endpoint}"

    client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.tikal-cloud.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(digitalocean_kubernetes_cluster.tikal-cloud.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.tikal-cloud.kube_config.0.cluster_ca_certificate)}"
    }

    resource "local_file" "kubeconfig" {
    filename = "./kube_config_cluster.yml"
    content  = "${digitalocean_kubernetes_cluster.tikal-cloud.kube_config.0.raw_config}"
    }
    ```

**Please note:** digital ocean certificates renew every 7 days so you probebly will use this small resource quite a lot (ot use digital ocean web to export it if you prefer...).

### 3. Running Terraform

    ```sh 

    $ terraform init

    Initializing provider plugins...

    The following providers do not have any version constraints in configuration,
    so the latest version was installed.

    To prevent automatic upgrades to new major versions that may contain breaking
    changes, it is recommended to add version = "..." constraints to the
    corresponding provider blocks in configuration, with the constraint strings
    suggested below.

    * provider.digitalocean: version = "~> 1.1"
    * provider.kubernetes: version = "~> 1.5"
    * provider.local: version = "~> 1.1"

    Terraform has been successfully initialized!

    You may now begin working with Terraform. Try running "terraform plan" to see
    any changes that are required for your infrastructure. All Terraform commands
    should now work.

    If you ever set or change modules or backend configuration for Terraform,
    rerun this command to reinitialize your working directory. If you forget, other
    commands will detect it and remind you to do so if necessary.

    $ terraform plan -out `basename $PWD`.out

    Refreshing Terraform state in-memory prior to plan...
    The refreshed state will be used to calculate this plan, but will not be
    persisted to local or remote state storage.


    ------------------------------------------------------------------------

    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
    + create

    Terraform will perform the following actions:

    + digitalocean_kubernetes_cluster.tikal-cloud
        id:                     <computed>
        cluster_subnet:         <computed>
        created_at:             <computed>
        endpoint:               <computed>
        ipv4_address:           <computed>
        kube_config.#:          <computed>
        name:                   "tikal-cloud"
        node_pool.#:            "1"
        node_pool.0.id:         <computed>
        node_pool.0.name:       "standard-pool"
        node_pool.0.node_count: "2"
        node_pool.0.nodes.#:    <computed>
        node_pool.0.size:       "s-2vcpu-2gb"
        region:                 "lon1"
        service_subnet:         <computed>
        status:                 <computed>
        tags.#:                 "1"
        tags.3382956491:        "tikal-cloud"
        updated_at:             <computed>
        version:                "1.12.1-do.2"

    + local_file.kubeconfig
        id:                     <computed>
        content:                "${digitalocean_kubernetes_cluster.tikal-cloud.kube_config.0.raw_config}"
        filename:               "./kube_config_cluster.yml"


    Plan: 2 to add, 0 to change, 0 to destroy.

    ------------------------------------------------------------------------

    This plan was saved to: digitalocean.out

    To perform exactly these actions, run the following command to apply:
        terraform apply "digitalocean.out"

    $ terraform apply `basename $PWD`.out

    digitalocean_kubernetes_cluster.tikal-cloud: Creating...
    cluster_subnet:         "" => "<computed>"
    created_at:             "" => "<computed>"
    endpoint:               "" => "<computed>"
    ipv4_address:           "" => "<computed>"
    kube_config.#:          "" => "<computed>"
    name:                   "" => "tikal-cloud"
    node_pool.#:            "" => "1"
    node_pool.0.id:         "" => "<computed>"
    node_pool.0.name:       "" => "standard-pool"
    node_pool.0.node_count: "" => "2"
    node_pool.0.nodes.#:    "" => "<computed>"
    node_pool.0.size:       "" => "s-2vcpu-2gb"
    region:                 "" => "lon1"
    service_subnet:         "" => "<computed>"
    status:                 "" => "<computed>"
    tags.#:                 "" => "1"
    tags.3382956491:        "" => "tikal-cloud"
    updated_at:             "" => "<computed>"
    version:                "" => "1.12.1-do.2"
    digitalocean_kubernetes_cluster.tikal-cloud: Still creating... (10s elapsed)
    ...
    digitalocean_kubernetes_cluster.tikal-cloud: Still creating... (3m10s elapsed)
    digitalocean_kubernetes_cluster.tikal-cloud: Creation complete after 3m12s (ID: 4d35b716-532c-4210-b0a8-07e224a52f5a)
    local_file.kubeconfig: Creating...
    (redacted)
    iMGZEcE9sdTlUSmN0MnIvalNUaTJObk45R1B1Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==\n"
    filename: "" => "./kube_config_cluster.yml"
    local_file.kubeconfig: Creation complete after 0s (ID: a813e11a1d8cc4c03f463b3386ed80fa4da9131d)

    Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
    ```

### 4. Get `up n running with kubernetes`:

* setup kubeconfig:
    ```sh
    export KUBECFG=$PWD/kube_config_cluster.yml
    ```

* Get `nodes` ...
    ```sh
    kubectl get  nodes
    NAME                      STATUS   ROLES    AGE     VERSION
    wonderful-bhaskara-umf4   Ready    <none>   3m48s   v1.12.1
    wonderful-bhaskara-umfh   Ready    <none>   3m47s   v1.12.1
    ```

## A little peak "Under the Hood"

A reltively short kubectl command ca reveal the pattern used by digital ocean `kubectl get po --all-namespaces` as you will see below:

```sh
kubectl get po --all-namespaces  -o wide
NAMESPACE     NAME                                 READY   STATUS    RESTARTS   AGE   IP              NODE                      NOMINATED NODE
kube-system   csi-do-controller-0                  4/4     Running   2          15m   10.244.6.2      wonderful-bhaskara-umf4   <none>
kube-system   csi-do-node-grmz8                    2/2     Running   0          10m   10.131.7.185    wonderful-bhaskara-umfh   <none>
kube-system   csi-do-node-tjbgg                    2/2     Running   0          10m   10.131.14.234   wonderful-bhaskara-umf4   <none>
kube-system   kube-dns-55cf9576c4-mj98r            3/3     Running   0          15m   10.244.6.3      wonderful-bhaskara-umf4   <none>
kube-system   kube-proxy-wonderful-bhaskara-umf4   1/1     Running   1          10m   10.131.14.234   wonderful-bhaskara-umf4   <none>
kube-system   kube-proxy-wonderful-bhaskara-umfh   1/1     Running   1          10m   10.131.7.185    wonderful-bhaskara-umfh   <none>
```

each droplet has a `csi-do-node-$id` which is tied to the "control plane as a service" of course the `kube-proxy` so traffic could be routed to the cluster and `kube-dns` for service discovery and dns for the cluster.

## Conclution
![http://preview.tikalk.com/media/do-demo-cluster.png](http://preview.tikalk.com/media/do-demo-cluster.png)

It's been a looong 3 years since spinning up a cluster is a pieace of cake such as this ...

Hope you find this post informative and useful as a starting point.

Yourse Sincerily,

Haggai Philip Zagury, Group & Tech Lead, Tikal DevOps team and FullStack Developers Israel Contributer.