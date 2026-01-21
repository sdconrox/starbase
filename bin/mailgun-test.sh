#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

OP_ITEM_ID='rqkjaudsqrmheggtgiqnliuaiq'

MAILGUN_API_KEY=$(op item get ${OP_ITEM_ID} --fields "api.api-key" --format json | jq -r '.value')
MAILGUN_BASE_URL=$(op item get ${OP_ITEM_ID} --fields "api.base-url" --format json | jq -r '.value')
MAILGUN_SANDBOX_DOMAIN=$(op item get ${OP_ITEM_ID} --fields "api.sandbox-domain" --format json | jq -r '.value')

TARGET_NAME='Shane'
TARGET_EMAIL='sdconrox@gmail.com'
FROM_EMAIL="postmaster@${MAILGUN_SANDBOX_DOMAIN}"

curl -s --user "api:${MAILGUN_API_KEY}" \
  ${MAILGUN_BASE_URL}/v3/${MAILGUN_SANDBOX_DOMAIN}/messages \
  -F from="Mailgun Sandbox <${FROM_EMAIL}>" \
  -F to="${TARGET_NAME} <${TARGET_EMAIL}>" \
  -F subject="Test email to ${TARGET_NAME}" \
  -F text="${TARGET_NAME}, this is a test email with the following identifier: 1 (op is working)" \
