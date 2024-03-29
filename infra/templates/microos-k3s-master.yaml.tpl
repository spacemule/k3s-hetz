#cloud-config
# Based on https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/modules/host/templates/userdata.yaml.tpl

##Variables defined in this file:
# k3s_token
# hostname
# control_ip
# cluster_cidr
# sshAuthorizedKeys
# public_ip
# region
# private_network
# hcloud_key

write_files:

# Configure the private network interface
#- content: |
#    BOOTPROTO='dhcp'
#    STARTMODE='auto'
#  path: /etc/sysconfig/network/ifcfg-eth1

# Apply manifests on boot
- content: |
    [Unit]
    Description=Apply manifests on boot

    [Timer]
    OnBootSec=30
    Persistent=true

    [Install]
    WantedBy=timers.target
  path: /etc/systemd/system/manifests.timer

- content: |
    [Unit]
    Description=Apply manifests

    [Service]
    Type=simple
    Environment="KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    ExecStart=kubectl apply -Rf /root/manifests/

    [Install]
    WantedBy=default.target
  path: /etc/systemd/system/manifests.service

# Enable routing

- content: |
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: iptables
    spec:
      template:
        spec:
          hostNetwork: true
          containers:
          - name: iptables
            image: registry.opensuse.org/home/spacemule/branches/opensuse/templates/images/tumbleweed/containers/opensuse/iptables
            imagePullPolicy: Always
            command: ["/bin/sh", "-c", "--",
              "iptables -A FORWARD -i eth1 -j ACCEPT; \
              iptables -A FORWARD -o eth1  -j ACCEPT; \
              iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; \
              iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE"]
            securityContext:
              capabilities:
                add: ["NET_ADMIN", "SYS_ADMIN"]
          restartPolicy: OnFailure
          nodeSelector:
            node-role.kubernetes.io/master: "true"
          tolerations:
            - key: "node-role.kubernetes.io/control-plane"
              operator: "Exists"
              effect: "NoSchedule"
            - key: "node-role.kubernetes.io/master"
              operator: "Exists"
              effect: "NoSchedule"
            - key: "node.cloudprovider.kubernetes.io/uninitialized"
              operator: "Exists"
              effect: "NoSchedule"
  path: /root/manifests/routing.yaml

# Install Hetzner CCM every boot (why not?!)

- content: |
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: cloud-controller-manager
      namespace: kube-system
    ---
    kind: ClusterRoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: system:cloud-controller-manager
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
      - kind: ServiceAccount
        name: cloud-controller-manager
        namespace: kube-system
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hcloud-cloud-controller-manager
      namespace: kube-system
    spec:
      replicas: 1
      revisionHistoryLimit: 2
      selector:
        matchLabels:
          app: hcloud-cloud-controller-manager
      template:
        metadata:
          labels:
            app: hcloud-cloud-controller-manager
          annotations:
            scheduler.alpha.kubernetes.io/critical-pod: ''
        spec:
          serviceAccountName: cloud-controller-manager
          dnsPolicy: Default
          tolerations:
            # this taint is set by all kubelets running `--cloud-provider=external`
            # so we should tolerate it to schedule the cloud controller manager
            - key: "node.cloudprovider.kubernetes.io/uninitialized"
              value: "true"
              effect: "NoSchedule"
            - key: "CriticalAddonsOnly"
              operator: "Exists"
            # cloud controller manages should be able to run on masters
            - key: "node-role.kubernetes.io/master"
              effect: NoSchedule
              operator: Exists
            - key: "node-role.kubernetes.io/control-plane"
              effect: NoSchedule
              operator: Exists
            - key: "node.kubernetes.io/not-ready"
              effect: "NoSchedule"
          hostNetwork: true
          containers:
            - image: hetznercloud/hcloud-cloud-controller-manager:v1.12.1
              name: hcloud-cloud-controller-manager
              command:
                - "/bin/hcloud-cloud-controller-manager"
                - "--cloud-provider=hcloud"
                - "--leader-elect=false"
                - "--allow-untagged-cloud"
                - "--allocate-node-cidrs=true"
                - "--cluster-cidr=${cluster_cidr}"
              resources:
                requests:
                  cpu: 100m
                  memory: 50Mi
              env:
                - name: NODE_NAME
                  valueFrom:
                    fieldRef:
                      fieldPath: spec.nodeName
                - name: HCLOUD_TOKEN
                  value: "${hcloud_key}"
                - name: HCLOUD_NETWORK
                  value: "${private_network}"
                - name: "HCLOUD_LOAD_BALANCERS_LOCATION"
                  value: "${region}"
                - name: "HCLOUD_LOAD_BALANCERS_USE_PRIVATE_IP"
                  value: "true"
  path: /root/manifests/ccm.yaml

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

# Set reboot method as "kured"
- content: |
    REBOOT_METHOD=kured
  path: /etc/transactional-update.conf

# Add ssh authorized keys
ssh_authorized_keys:
%{ for key in sshAuthorizedKeys ~}
  - ${key}
%{ endfor ~}

# Resize /var, not /, as that's the last partition in MicroOS image.
growpart:
    devices: ["/var"]

# Make sure the hostname is set correctly
hostname: ${hostname}
preserve_hostname: true

runcmd:

# As above, make sure the hostname is not reset
- [sed, '-i', 's/NETCONFIG_NIS_SETDOMAINNAME="yes"/NETCONFIG_NIS_SETDOMAINNAME="no"/g', /etc/sysconfig/network/config]
- [sed, '-i', 's/DHCLIENT_SET_HOSTNAME="yes"/DHCLIENT_SET_HOSTNAME="no"/g', /etc/sysconfig/network/dhcp]

# We set Cloudflare DNS servers, followed by Google as a backup
- [sed, '-i', 's/NETCONFIG_DNS_STATIC_SERVERS=""/NETCONFIG_DNS_STATIC_SERVERS="1.1.1.1 1.0.0.1 8.8.8.8"/g', /etc/sysconfig/network/config]

# Bounds the amount of logs that can survive on the system
- [sed, '-i', 's/#SystemMaxUse=/SystemMaxUse=3G/g', /etc/systemd/journald.conf]
- [sed, '-i', 's/#MaxRetentionSec=/MaxRetentionSec=1week/g', /etc/systemd/journald.conf]

# Reduces the default number of snapshots from 2-10 number limit, to 4 and from 4-10 number limit important, to 2
- [sed, '-i', 's/NUMBER_LIMIT="2-10"/NUMBER_LIMIT="4"/g', /etc/snapper/configs/root]
- [sed, '-i', 's/NUMBER_LIMIT_IMPORTANT="4-10"/NUMBER_LIMIT_IMPORTANT="3"/g', /etc/snapper/configs/root]

# Disables unneeded services and enables routing
- [systemctl, disable, '--now', 'rebootmgr.service']
- systemctl daemon-reload
- systemctl enable manifests.timer

# Installs k3s
- curl -sfL https://get.k3s.io > /tmp/k3s.sh
- INSTALL_K3S_EXEC="--flannel-iface=eth1 --tls-san ${public_ip} --cluster-cidr=${cluster_cidr} --kubelet-arg=cloud-provider=external --node-taint=node-role.kubernetes.io/control-plane:NoSchedule --node-taint=node-role.kubernetes.io/master:NoSchedule  --disable local-storage --disable traefik --disable-cloud-controller --disable-network-policy --node-ip=${control_ip} --flannel-backend=wireguard --token=${k3s_token}" sh /tmp/k3s.sh

# Install packages
- transactional-update --non-interactive --continue dup
- transactional-update --non-interactive --continue pkg install python3-selinux open-iscsi wireguard-tools nfs-client

# Persist sysctl config
- sysctl -p

# Reboot
power_state:
    mode: reboot
    condition: True