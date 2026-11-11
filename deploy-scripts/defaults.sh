#! /bin/bash -e

# Script defaults
DEPLOY_DIR=.deploy
DEPLOY_INDICATOR=.deploying
DEPLOY_TOKEN_FILE=.deploy-token

HAS_GIT_SUBMODULES=false

HAS_LATEX_PODMAN_SERVICE=false
LATEX_PODMAN_USER=bobv-latex-pdflatex

STOP_RUNNING_MESSENGER_WORKERS=false

SYSTEMD_SERVICES=()

SYSTEMD_MESSENGER_BASENAME_DEFAULT="symfony-messenger"
MESSENGER_QUEUES=()

REPLACE_ASSETS=false
ASSET_PATHS=(
  "public/build"
)

RUN_BACK_ONLINE=true

function pre_offline_hook() {
  echo "pre_offline_hook - override to customise"
}

function pre_restore_hook() {
  echo "pre_restore_hook - override to customise"
}

function pre_remove_deploy_dir_hook() {
  echo "pre_remove_deploy_dir_hook - override to customise"
}
