#!/usr/bin/env bash
# Write gitignored pull-secret files from env.local.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
env_file="$root/env.local"

if [[ ! -f "$env_file" ]]; then
  echo "Missing $env_file. Copy env.local.example and fill it in." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

okd_dest="$root/2-okd-bastion-ansible/files/pull_secret.txt"
ocp_dest="$root/4-ocp-bastion-ansible/files/pull_secret.txt"

printf '%s\n' "$OKD_PULL_SECRET" > "$okd_dest"
printf '%s\n' "$OCP_PULL_SECRET" > "$ocp_dest"
chmod 600 "$okd_dest" "$ocp_dest"

echo "Wrote pull secrets to:"
echo "  $okd_dest"
echo "  $ocp_dest"
