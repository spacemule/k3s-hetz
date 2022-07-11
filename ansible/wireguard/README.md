### AWS Wireguard Setup

### Usage

- Initial use
    1. Set variables for desired VPN set up, region, VPC, subnet, etc.
    2. If SSH not allowed in VPC, ensure at least one client is specified
    3. Apply terraform
- Adding clients
    1. From `ansible` directory run `mkkey.sh $DESIRED_USERNAME`
    2. Copy the output to `clients` variable in `vars/${var-file}.yml`
    3. Edit the IP address of the client to an IP in the VPN's subnet
    4. Run the playbook `ansible-playbook -i inventory.imi --extra-vars "@./vars/{$var-file}.yml --vault-password-file ./vault.key wireguard.yml`
- Removing clients
    1. Remove the desired client entry from `client_conf/all.yml`
    2. Run the playbook `ansible-playbook -i inventory.imi --extra-vars "@./vars/{$var-file}.yml --vault-password-file ./vault.key wireguard.yml`
- Connecting to VPN
    1. After applying the playbook, client config files are created/updated in the `client_conf/${output_dir}` directory
    2. Securely transfer the file `${USER}.conf` to the user
       - Linux NetworkManager
            1. Run `nmcli connection import type wireguard file ${USER}.conf`
            2. The connection is now available for all users on the system and can be edited in NetworkManager
       - Linux wg-quick
            1. With root privileges run `wg-quick up /path/to/${USER}.conf`
            2. To disconnect run `wg-quick down /path/to/${USER}.conf`
       - Linux systemd
            1. Copy `${USER}.conf` to `/etc/wireguard/`
            2. Run `systemctl enable --now wg-quick@$USER` (For example, if the config file is `noah.conf` run `systemctl enable --now wg-quick@noah`)
       - Windows
            1. TBD
       - Android
            1. Install wireguard client
            2. Import `${USER}.conf` to client and start the connection

### Plans

- Remove dependence on aws-wireguard module
- Implement healthcheck outside of scaling group
