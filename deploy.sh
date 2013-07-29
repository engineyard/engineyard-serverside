#!/usr/bin/env bash

engineyard-serverside deploy --verbose \
  --account-name serverside-testing \
  --app serverside \
  --config '{"input_ref":"cee5f8da5d2b7b3aebceb97cac0ce126110bec50","deployed_by":"The Mothership","strategy":"Package"}' \
  --uri https://github.com/engineyard/todo/archive/master.zip \
  --environment-name production \
  --framework-env production \
  --instances localhost
