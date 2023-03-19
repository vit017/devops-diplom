terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      #version = "0.82.0"
    }
  }
}

provider "yandex" {
  #token     = file("ya_token")
  cloud_id  = "b1gb2fv47foenqc1r8pb"
  folder_id = "b1g9fu0ivrlug47rtrmh" #folder2
  #folder_id = "b1g54eujvl1abu6fhu8d" #default
  zone      = var.zone
  service_account_key_file = file("authorized_key.json")
}

resource "yandex_vpc_network" "network" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "my-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_iam_service_account" "node_sa" {
  name = "my-node-sa"
}

output "node_service_account_id" {
  value = yandex_iam_service_account.node_sa.id
}

resource "yandex_vpc_security_group" "group1" {
  name        = "My security group"
  description = "description for my security group"
  network_id  = yandex_vpc_network.network.id

  labels = {
    my-label = "my-label-value"
  }

  ingress {
    protocol       = "TCP"
    description    = "rule1 description"
    v4_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
    port           = 8080
  }

  egress {
    protocol       = "ANY"
    description    = "rule2 description"
    v4_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
    from_port      = 8090
    to_port        = 8099
  }

  egress {
    protocol       = "UDP"
    description    = "rule3 description"
    v4_cidr_blocks = ["10.0.1.0/24"]
    from_port      = 8090
    to_port        = 8099
  }
}

resource "yandex_kubernetes_cluster" "my_cluster" {
  name       = "my-cluster"
  network_id = yandex_vpc_network.network.id

  master {
    #version = "1.17"
    zonal {
      zone      = var.zone
      subnet_id = yandex_vpc_subnet.subnet.id
    }

    public_ip = true

    #security_group_ids = ["${yandex_vpc_security_group.group1.id}"]
  }

  service_account_id      = file("src_acc_id")
  node_service_account_id = yandex_iam_service_account.node_sa.id

  labels = {
    my_key       = "my_value"
    my_other_key = "my_other_value"
  }

  release_channel = "RAPID"
  #network_policy_provider = "CALICO"
}

# Configuring kubectl locally
resource "null_resource" "k8s_config" {
  depends_on = [
    yandex_kubernetes_cluster.my_cluster
  ]
  #provisioner "local-exec" {
    #command = "yc managed-kubernetes cluster get-credentials --external --name my_cluster"
  #}
}

resource "yandex_kubernetes_node_group" "my_node_group" {
  cluster_id  = "${yandex_kubernetes_cluster.my_cluster.id}"
  name        = "nodesgroup"
  description = "description"
  version     = "1.24"

  labels = {
    "key" = "value"
  }

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat                = true
      subnet_ids         = ["${yandex_vpc_subnet.subnet.id}"]
    }

    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 30
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }
}

resource "yandex_compute_instance" "srv" {
  name        = "srv"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8emvfmfoaordspe1jr"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.subnet.id}"
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}