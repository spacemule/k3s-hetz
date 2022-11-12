variable "hcloud_token" {
  type = string
}

variable "microos-url" {
  type    = string
  default = "https://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-OpenStack-Cloud.qcow2"
}

variable "jeos-url" {
  type    = string
  default = "https://download.opensuse.org/distribution/leap/15.4/appliances/openSUSE-Leap-15.4-JeOS.x86_64-OpenStack-Cloud.qcow2"
}

packer {
  required_plugins {
    hetznercloud = {
      source  = "github.com/hashicorp/hcloud"
      version = ">=1.0.5"
    }
  }
}

#source "hcloud" "microos-base" {
#  token         = var.hcloud_token
#  server_type   = "cpx11"
#  location      = "hel1"
#  image         = "rocky-9"
#  ssh_username  = "root"
#  rescue        = "linux64"
#  snapshot_name = "microos-packer-base"
#  snapshot_labels = {
#    "packer" = "true"
#    "type"   = "base"
#    "OS"     = "microos"
#  }
#}
#
#build {
#  sources = [
#    "source.hcloud.microos-base"
#  ]
#
#  provisioner "shell" {
#    inline = [
#      "apt-get update",
#      "apt-get install -y qemu-utils wget",
#      "wget -O /tmp/microos.qcow2 ${var.microos-url}",
#      "qemu-img convert -p -f qcow2 -O host_device /tmp/microos.qcow2 /dev/sda",
#      "sync",
#      "reboot"
#    ]
#    expect_disconnect = true
#  }
#  provisioner "shell" {
#    inline = [
#      "systemctl disable --now wicked && systemctl enable --now NetworkManager",
#      "transactional-update pkg install -y systemd-network",
#      "echo -e \"[Match]\n Name=eth*\n[Network]\n DHCP=yes\" > /etc/systemd/network/default.network",
#      "cloud-init clean",
#      "history -c",
#    ]
#  }
#}

source "hcloud" "jeos-base" {
  token         = var.hcloud_token
  server_type   = "cpx11"
  location      = "hel1"
  image         = "rocky-9"
  ssh_username  = "root"
  rescue        = "linux64"
  snapshot_name = "jeos-packer-base"
  snapshot_labels = {
    "packer" = "true"
    "type"   = "base"
    "OS"     = "openSUSE"
  }
}

build {
  sources = [
    "source.hcloud.jeos-base"
  ]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y qemu-utils wget",
      "wget --waitretry=5 --retry-connrefused -O /tmp/jeos.qcow2 ${var.jeos-url}",
      "qemu-img convert -p -f qcow2 -O host_device /tmp/jeos.qcow2 /dev/sda",
      "sync",
      "reboot"
    ]
    expect_disconnect = true
  }
  provisioner "shell" {
    inline = [
      "zypper in -y NetworkManager cloud-init",
      "systemctl disable --now wicked && systemctl enable --now NetworkManager",
      "cloud-init clean",
      "history -c",
    ]
  }
}