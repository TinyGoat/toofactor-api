#!/bin/bash
#
echo "hmset customer:1000 \
  email foo@bar.com \
  oauth_token 99999 \
  cc_token 000000000 \
  last_billed 0 \
  api 1000 \
  xml_access 0 \
  json_access 0 \
  sms_access 0 \
  last_token 0 \
  last_client_url 0 \
  last_access 0 \
  trial_account 0 \
  expired 0" | redis-cli

echo "set customer:1234 foo" | redis-cli
