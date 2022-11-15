#cloud-config
# Stolen from https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/modules/host/templates/userdata.yaml.tpl

# default_route_ip
# hostname
# private_ip
# sshAuthorizedKeys

write_files:

# Redis config
- content: |
    bind 127.0.0.1 ${private_ip}
    #bind-source-addr ${private_ip}
    protected-mode no
    port 6379
    tcp-backlog 511
    timeout 60
    tcp-keepalive 300
    supervised systemd
    pidfile /var/run/redis_6379.pid
    syslog-enabled yes
    syslog-ident redis
    syslog-facility local0
    databases 16
    save ""
  path: /etc/redis/redis.conf

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

# We set Cloudflare DNS servers, followed by Google as a backup
- [sed, '-i', 's/NETCONFIG_DNS_STATIC_SERVERS=""/NETCONFIG_DNS_STATIC_SERVERS="1.1.1.1 1.0.0.1 8.8.8.8"/g', /etc/sysconfig/network/config]

# Bounds the amount of logs that can survive on the system
- [sed, '-i', 's/#SystemMaxUse=/SystemMaxUse=3G/g', /etc/systemd/journald.conf]
- [sed, '-i', 's/#MaxRetentionSec=/MaxRetentionSec=1week/g', /etc/systemd/journald.conf]

# Install packages
- dnf update -y
- dnf install -y redis postgresql-server postgresql-contrib dnf-automatic
- systemctl daemon-reload
- systemctl enable --now dnf-automatic.timer
- systemctl disable --now firewalld

- sysctl -p

# Reboot
power_state:
    mode: reboot
    condition: True