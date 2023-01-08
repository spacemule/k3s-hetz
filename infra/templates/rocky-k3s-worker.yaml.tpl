#cloud-config
# Based on https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/modules/host/templates/userdata.yaml.tpl

##Variables defined in this file:
# k3s_token
# k3s_version
# default_route_ip
# hostname
# control_ip
# node_ip
# sshAuthorizedKeys

write_files:
# Ensure kernel modules load for k3s
- content: |
      overlay
      br_netfilter
      nf_conntrack
      iptable_nat
  path: /etc/modules-load.d/k3s.conf

# Enable IP forwarding
- content: |
    net.ipv4.ip_forward = 1
  path: /etc/sysctl.d/10-networking.conf

# Disable ssh password authentication
- content: |
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
    HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com
    ChallengeResponseAuthentication no
    PasswordAuthentication no
    PermitTunnel yes
    AllowTcpForwarding yes
    MaxAuthTries 2
    AuthorizedKeysFile .ssh/authorized_keys
  path: /etc/ssh/sshd_config.d/kube-hetzner.conf

# Add ssh authorized keys
ssh_authorized_keys:
%{ for key in sshAuthorizedKeys ~}
  - ${key}
%{ endfor ~}

# Make sure the hostname is set correctly
hostname: ${hostname}
preserve_hostname: true

runcmd:
# Remove hetzner networking helpers---more harm than good
- dnf remove -y hc-utils
# Add a connection on private iface
- nmcli connection add type ethernet con-name private ifname enp7s0 autoconnect yes
- nmcli connection modify private ipv4.dns 9.9.9.9
- nmcli connection up private
- nmcli device set enp7s0 managed yes

# Bounds the amount of logs that can survive on the system
- [sed, '-i', 's/#SystemMaxUse=/SystemMaxUse=3G/g', /etc/systemd/journald.conf]
- [sed, '-i', 's/#MaxRetentionSec=/MaxRetentionSec=1week/g', /etc/systemd/journald.conf]

# Install K3S
- curl -sfL https://get.k3s.io > /tmp/k3s.sh
- INSTALL_K3S_VERSION="${k3s_version}" INSTALL_K3S_EXEC="--flannel-iface=enp7s0 --node-ip=${node_ip} --kubelet-arg=cloud-provider=external" K3S_TOKEN="${k3s_token}" K3S_URL="https://${control_ip}:6443" sh /tmp/k3s.sh

# Install packages
- dnf install python3-dnf-plugin-versionlock -y
- dnf versionlock cloud-init
- dnf update -y
- dnf install -y iscsi-initiator-utils wireguard-tools nfs-utils dnf-automatic yum-utils
- systemctl daemon-reload
- systemctl enable --now dnf-automatic.timer iscsid.service
- systemctl disable --now firewalld nm-cloud-setup.service nm-cloud-setup.timer

# Persist sysctl config
- sysctl -p

# Reboot
power_state:
    mode: reboot
    condition: True