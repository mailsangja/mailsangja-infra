#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/seal-secret.sh <namespace> <secret-name> <env-file> <output-file>

Example:
  scripts/seal-secret.sh \
    mailsangja \
    mailsangja-app-secret \
    /private/tmp/mailsangja-app.secret.env \
    apps/mailsangja/sealedsecret-app.yaml

Notes:
  - The env file must use KEY=value lines accepted by kubectl --from-env-file.
  - Keep the env file outside this repository, or name it *.secret.env.
  - The generated output file is safe to commit as a SealedSecret manifest.
  - Sealing uses strict scope, so namespace and secret name are fixed.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 4 ]]; then
  usage >&2
  exit 1
fi

namespace="$1"
secret_name="$2"
env_file="$3"
output_file="$4"

if [[ ! -f "$env_file" ]]; then
  echo "error: env file not found: $env_file" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "error: kubectl is required" >&2
  exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "error: kubeseal is required" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_file")"

kubectl create secret generic "$secret_name" \
  --namespace "$namespace" \
  --from-env-file "$env_file" \
  --dry-run=client \
  -o yaml \
| kubeseal \
  --controller-name sealed-secrets-controller \
  --controller-namespace sealed-secrets \
  --scope strict \
  --format yaml \
> "$output_file"

echo "Generated SealedSecret: $output_file"
echo
echo "Review the manifest, then commit it. Do not commit the source env file."
