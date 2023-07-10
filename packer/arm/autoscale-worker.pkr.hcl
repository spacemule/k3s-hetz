packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/hcloud"
    }
  }
}

variable "hcloud_token" {
  type = string
}

source "hcloud" "worker" {
  token         = var.hcloud_token
  server_type   = "cax11"
  image         = "rocky-9"
  location      = "fsn1"
  ssh_username  = "root"
  snapshot_name = "k3s-worker-arm"
  snapshot_labels = {
    "type" = "worker"
  }
  user_data_file = "../../hetz/unsealed/userdata.yaml"
}

build {
  sources = ["source.hcloud.worker"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
    ]
  }
}
