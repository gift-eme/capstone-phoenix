#!/usr/bin/env bash
# Applies the ClusterIssuers with LETSENCRYPT_EMAIL substituted in from the
# gitignored .env here (copy .env.example) — keeps the real email out of the
# committed YAML, same reason terraform.tfvars/group_vars stay out of git.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
source "$SCRIPT_DIR/.env"
set +a

for f in clusterissuer-staging.yaml clusterissuer-production.yaml; do
  envsubst < "$SCRIPT_DIR/$f" | kubectl apply -f -
done
