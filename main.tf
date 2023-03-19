terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.82.0"
    }
  }
}

provider "yandex" {
  token     = file("ya_token")
  cloud_id  = "b1gtnh7joibadt3ak23b"
  folder_id = "b1g2dbf4td7db1lu2hmr"
  zone      = var.zone
}

resource "yandex_compute_instance" "master" {
  name        = "k8s-master"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8mpuj4fo4e4a4d4oh8"
      size     = 20
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "node" {
  name        = "k8s-node"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8mpuj4fo4e4a4d4oh8"
      size     = 20
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "lab-net" {
  name = "lab-network"
}

resource "yandex_vpc_subnet" "my-subnet" {
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone           = var.zone
  network_id     = "${yandex_vpc_network.lab-net.id}"
}

resource "yandex_kubernetes_cluster" "zonal_cluster_resource_name" {
  name        = "cluster-k8s"
  description = "description"

  network_id = "${yandex_vpc_network.lab-net.id}"

  master {
    version = "1.17"
    zonal {
      zone      = var.zone
      subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    }

    public_ip = true

    security_group_ids = ["${yandex_vpc_security_group.group1.id}"]

    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "15:00"
        duration   = "3h"
      }
    }
  }

  node_pool {
    name = "default-pool"
    node_count = 1
    resources {
      cores = 2
      memory = 4
    }
  }

  service_account_id      = file("src_acc_id")"${yandex_iam_service_account.service_account_resource_name.id}"
  node_service_account_id = "${yandex_iam_service_account.node_service_account_resource_name.id}"

  labels = {
    my_key       = "my_value"
    my_other_key = "my_other_value"
  }
}

resource "yandex_kubernetes_node_group" "my_node_group" {
  cluster_id  = "${yandex_kubernetes_cluster.zonal_cluster_resource_name.id}"
  name        = "my_node_group"
  description = "description"
  version     = "1.17"

  labels = {
    "key" = "value"
  }

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat                = true
      subnet_ids         = ["${yandex_vpc_subnet.my-subnet.id}"]
    }

    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
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

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      day        = "monday"
      start_time = "15:00"
      duration   = "3h"
    }

    maintenance_window {
      day        = "friday"
      start_time = "10:00"
      duration   = "4h30m"
    }
  }
}

resource "yandex_vpc_network" "lab-net" {
  name = "lab-network"
}

resource "yandex_vpc_security_group" "group1" {
  name        = "My security group"
  description = "description for my security group"
  network_id  = "${yandex_vpc_network.lab-net.id}"

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