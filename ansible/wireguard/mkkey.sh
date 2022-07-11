#!/bin/bash
# Generates keys and formats a client entry to the group_vars/all.yml file.
# Usage: ./mkkey.sh $desired_user_name
# NOTE: Requires "vault.key"
# Make sure to fill in the IP address of the client
# Edit the listen port if desired
# Paste into the all.yml file, and run the playbook

set -eo pipefail

key=$(wg genkey)
pubkey=$(echo -n $key | wg pubkey)
key=$(echo -n $key | ansible-vault encrypt_string --vault-password-file=./vault.key)
psk=$(wg genpsk | ansible-vault encrypt_string --vault-password-file=./vault.key)

cat << EOF
  - name: $1
    public_key: $pubkey
    key: $key
    psk: $psk
    ip: 10.10.10.XXX
    port: 51280
EOF

exit 0
