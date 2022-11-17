#cloud-config
# Based on https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/modules/host/templates/userdata.yaml.tpl

##Variables defined in this file:
# k3s_token
# k3s_version
# hostname
# control_ip
# cluster_cidr
# sshAuthorizedKeys
# public_ip
# region
# private_network
# hcloud_key

write_files:

# Ensure kernel modules load for k3s
- content: |
    overlay
    br_netfilter
    nf_conntrack
    iptable_nat
  path: /etc/modules-load.d/k3s.conf

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
    After=k3s.service

    [Service]
    Type=simple
    Environment="KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    ExecStart=kubectl apply -Rf /root/manifests/

    [Install]
    WantedBy=default.target
  path: /etc/systemd/system/manifests.service

- content: |
    [Unit]
    Description=Delete job manifests on boot

    [Timer]
    OnBootSec=30
    Persistent=true

    [Install]
    WantedBy=timers.target
  path: /etc/systemd/system/delete-jobs.timer

- content: |
    [Unit]
    Description=Delete job manifests
    After=k3s.service
    After=manifests.service

    [Service]
    Type=simple
    Environment="KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    ExecStart=kubectl delete -f /root/manifests/routing.yaml

    [Install]
    WantedBy=default.target
  path: /etc/systemd/system/delete-jobs.service

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
              "iptables -A FORWARD -i enp7s0 -j ACCEPT; \
              iptables -A FORWARD -o enp7s0  -j ACCEPT; \
              iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; \
              iptables -t nat -A POSTROUTING -o enp7s0 -j MASQUERADE"]
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
                    - key: "node-role.kubernetes.io/control-plane"
                      effect: NoSchedule
                    - key: "node.kubernetes.io/not-ready"
                      effect: "NoSchedule"
                containers:
                    - image: hetznercloud/hcloud-cloud-controller-manager:v1.13.2
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
                          - name: HCLOUD_LOAD_BALANCERS_ENABLED
                            value: "false"
                priorityClassName: system-cluster-critical
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

# Add ssh authorized keys
ssh_authorized_keys:
%{ for key in sshAuthorizedKeys ~}
  - ${key}
%{ endfor ~}

# Make sure the hostname is set correctly
hostname: ${hostname}
preserve_hostname: true

runcmd:

# Bounds the amount of logs that can survive on the system
- [sed, '-i', 's/#SystemMaxUse=/SystemMaxUse=3G/g', /etc/systemd/journald.conf]
- [sed, '-i', 's/#MaxRetentionSec=/MaxRetentionSec=1week/g', /etc/systemd/journald.conf]

# Installs k3s
- curl -sfL https://get.k3s.io > /tmp/k3s.sh
- INSTALL_K3S_VERSION="${k3s_version}" INSTALL_K3S_EXEC="--flannel-iface=enp7s0 --tls-san ${public_ip} --cluster-cidr=${cluster_cidr} --kubelet-arg=cloud-provider=external --node-taint=node-role.kubernetes.io/control-plane:NoSchedule --node-taint=node-role.kubernetes.io/master:NoSchedule  --disable local-storage --disable traefik --disable-cloud-controller --disable-network-policy --node-external-ip=${public_ip} --node-ip=${control_ip} --token=${k3s_token}" sh /tmp/k3s.sh

# Install packages
- dnf update -y
- dnf install -y iscsi-initiator-utils wireguard-tools nfs-utils dnf-automatic

# Enables routing and automatic updates
- systemctl daemon-reload
- systemctl enable manifests.timer delete-jobs.timer
- systemctl enable --now dnf-automatic.timer
- systemctl disable --now firewalld nm-cloud-setup.service nm-cloud-setup.timer


    # Persist sysctl config
- sysctl -p

# Reboot
power_state:
    mode: reboot
    condition: True