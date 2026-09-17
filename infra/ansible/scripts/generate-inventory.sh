#!/usr/bin/env bash
# Regenerates inventory/hosts.yaml and inventory/group_vars/all.yml straight
# from `terraform output` — no hand-typed/hardcoded node IPs or CIDRs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../../terraform"
INVENTORY="$SCRIPT_DIR/../inventory/hosts.yaml"
GROUP_VARS="$SCRIPT_DIR/../inventory/group_vars/all.yml"

export TF_OUTPUT_JSON="$(terraform -chdir="$TF_DIR" output -json)"

mkdir -p "$(dirname "$GROUP_VARS")"

python3 - "$INVENTORY" "$GROUP_VARS" <<'PY'
import json
import os
import sys

data = json.loads(os.environ["TF_OUTPUT_JSON"])
inventory_path = sys.argv[1]
group_vars_path = sys.argv[2]

server_pub = data["server_public_ip"]["value"]
server_priv = data["server_private_ip"]["value"]
worker_pubs = data["worker_public_ips"]["value"]
worker_privs = data["worker_private_ips"]["value"]
admin_cidrs = data["admin_cidrs"]["value"]
vpc_cidr = data["vpc_cidr"]["value"]

worker_hosts = "\n".join(
    f"        worker-{i}:\n"
    f"          ansible_host: {pub}\n"
    f"          k3s_private_ip: {priv}"
    for i, (pub, priv) in enumerate(zip(worker_pubs, worker_privs), start=1)
)

inventory_content = f"""all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/taskappkey-created
  children:
    server:
      hosts:
        control-plane:
          ansible_host: {server_pub}
          k3s_private_ip: {server_priv}
    agents:
      hosts:
{worker_hosts}
"""

admin_cidrs_yaml = "\n".join(f'  - "{c}"' for c in admin_cidrs)
group_vars_content = f"""# Generated from `terraform output` — do not hand-edit, do not commit.
admin_cidrs:
{admin_cidrs_yaml}
vpc_cidr: "{vpc_cidr}"
"""

with open(inventory_path, "w") as f:
    f.write(inventory_content)
print(f"Wrote {inventory_path}")

with open(group_vars_path, "w") as f:
    f.write(group_vars_content)
print(f"Wrote {group_vars_path}")
PY
