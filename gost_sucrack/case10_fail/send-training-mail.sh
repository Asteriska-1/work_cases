#!/usr/bin/env bash

set -euo pipefail
umask 077

# ============================================================
# Settings
# ============================================================

ATTACHMENT_FILE="/opt/mail-trigger/IT-48217_Network_Diagnostics.zip"
SENT_FLAG="/var/lib/mail-trigger/completed.flag"

FROM_ADDRESS="helpdesk@edtechlab.local"
FROM_NAME="EdTech IT Service Desk"

# ============================================================
# Prevent duplicate delivery
# ============================================================

if [[ -f "${SENT_FLAG}" ]]; then
  exit 0
fi

# ============================================================
# Recipient
# ============================================================

STUDENT_ID="$(
  hostname |
    grep -oE 'student[0-9]+' ||
    true
)"

if [[ -z "${STUDENT_ID}" ]]; then
  echo "ERROR: student ID was not found in hostname" >&2
  exit 1
fi

if [[ ! -r "${ATTACHMENT_FILE}" ]]; then
  echo "ERROR: attachment is not readable: ${ATTACHMENT_FILE}" >&2
  exit 1
fi

TO_ADDRESS="${STUDENT_ID}@edtechlab.local"
ATTACHMENT_NAME="$(basename "${ATTACHMENT_FILE}")"

# ============================================================
# MIME message
# ============================================================

BOUNDARY="----=_MailPart_$(date +%s)_${RANDOM}"
MESSAGE_FILE="$(mktemp /tmp/training-mail.XXXXXX.eml)"

trap 'rm -f "${MESSAGE_FILE}"' EXIT

{
  printf 'From: %s <%s>\r\n' \
    "${FROM_NAME}" \
    "${FROM_ADDRESS}"

  printf 'To: %s\r\n' "${TO_ADDRESS}"
  printf 'Subject: IT-48217: Workstation network diagnostics required\r\n'
  printf 'Date: %s\r\n' "$(LC_ALL=C date -R)"
  printf 'MIME-Version: 1.0\r\n'
  printf 'Content-Type: multipart/mixed; boundary="%s"\r\n' \
    "${BOUNDARY}"
  printf '\r\n'

  printf -- '--%s\r\n' "${BOUNDARY}"
  printf 'Content-Type: text/plain; charset=UTF-8\r\n'
  printf 'Content-Transfer-Encoding: 8bit\r\n'
  printf '\r\n'

  printf '%s\r\n' \
    'Hello,' \
    '' \
    'The endpoint monitoring system reports that this workstation has not completed the connectivity validation required after the latest network policy update.' \
    '' \
    'Please complete ticket IT-48217:' \
    '1. Save the attached archive to your Downloads folder.' \
    '2. Extract its contents.' \
    '3. Run EdTech_Network_Diagnostics.exe.' \
    '' \
    'The utility will close automatically after collecting the diagnostic data. Administrator privileges are not required.' \
    '' \
    'Regards,' \
    'EdTech IT Service Desk'

  printf '\r\n'
  printf -- '--%s\r\n' "${BOUNDARY}"
  printf 'Content-Type: application/zip; name="%s"\r\n' \
    "${ATTACHMENT_NAME}"
  printf 'Content-Disposition: attachment; filename="%s"\r\n' \
    "${ATTACHMENT_NAME}"
  printf 'Content-Transfer-Encoding: base64\r\n'
  printf '\r\n'

  base64 -w 76 "${ATTACHMENT_FILE}" |
    sed 's/$/\r/'

  printf '\r\n'
  printf -- '--%s--\r\n' "${BOUNDARY}"
} > "${MESSAGE_FILE}"

# ============================================================
# Delivery
# ============================================================

curl \
  --fail \
  --silent \
  --show-error \
  --url smtp://127.0.0.1:1025 \
  --mail-from "${FROM_ADDRESS}" \
  --mail-rcpt "${TO_ADDRESS}" \
  --upload-file "${MESSAGE_FILE}"

touch "${SENT_FLAG}"
