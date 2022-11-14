terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.82.0"
    }
  }
}

provider "yandex" {
  token                    = file("ya_token")
  cloud_id                 = "dn2tlbmmlb6qravj9hm2"
  folder_id                = "b1gjfmv3qse9lq1r8m1s"
  zone                     = var.zone
}

resource "yandex_compute_instance" "my-instance-1" {
  name        = "test1"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8lur056bsfs83gfnvm" # lemp
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "my-instance-2" {
  name        = "test2"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8pud26a17jdkbf9ecb" # lamp
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    nat = true
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

resource "yandex_lb_target_group" "my-target-group" {
  name      = "my-target-group"
  region_id = var.region

  target {
    subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    address   = "${yandex_compute_instance.my-instance-1.network_interface.0.ip_address}"
  }

  target {
    subnet_id = "${yandex_vpc_subnet.my-subnet.id}"
    address   = "${yandex_compute_instance.my-instance-2.network_interface.0.ip_address}"
  }
}

resource "yandex_lb_network_load_balancer" "balancer1" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.my-target-group.id}"

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}