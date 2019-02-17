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