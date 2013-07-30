#!/usr/bin/env bash

engineyard-serverside deploy --verbose \
  --account-name serverside-testing \
  --app serverside \
  --config '{"deployed_by":"The Mothership"}' \
  --environment-name production \
  --framework-env production \
  --instances localhost \
  --archive https://github.com/engineyard/todo/archive/master.zip
  # --ref master \
  # --git https://github.com/engineyard/todo.git
