#! /bin/bash -e

# Ensure project API endpoint is set
if [[ -z "$PROJECT_API_ENDPOINT" ]]; then
  echo "Project API endpoint not set"
  exit 1
fi

# Retrieve token from file
PRIVATE_TOKEN=$(cat ${DEPLOY_TOKEN_FILE})
if [[ -z "$PRIVATE_TOKEN" ]]; then
  echo "Private token not found"
  exit 1
fi

# Retrieve pipeline id from original command
PIPELINE_ID=${SSH_ORIGINAL_COMMAND}
if [[ -z "$PIPELINE_ID" ]]; then
  echo "Pipeline id not supplied"
  exit 1
fi

# Determine the messenger base service name
if [[ -f .systemd_messenger_basename ]]; then
  SYSTEMD_MESSENGER_BASENAME=$(cat .systemd_messenger_basename)
fi
if [[ -z "$SYSTEMD_MESSENGER_BASENAME" ]]; then
  SYSTEMD_MESSENGER_BASENAME="${SYSTEMD_MESSENGER_BASENAME_DEFAULT}"
fi

# Retrieve the required artifacts
JOB_INFO=$(curl -sS --header "PRIVATE-TOKEN: ${PRIVATE_TOKEN}" "${PROJECT_API_ENDPOINT}/pipelines/${PIPELINE_ID}/jobs")
ASSET_JOB_ID=$(echo "${JOB_INFO}" | jq '.[] | select(.name == "build-assets" and .status == "success" and .artifacts_file != null) | .id')
DEPLOY_BRANCH=$(echo "${JOB_INFO}" | jq -r '.[] | select(.name == "build-assets" and .status == "success" and .artifacts_file != null) | .ref')

if [[ -z "$ASSET_JOB_ID" ]]; then
  echo "Required asset artifact not found in pipeline #${PIPELINE_ID}"
  exit 1
fi

rm -rf ${DEPLOY_DIR}
mkdir ${DEPLOY_DIR}

echo "Downloading assets artifact for job #${ASSET_JOB_ID}..."
curl -sS --header "PRIVATE-TOKEN: ${PRIVATE_TOKEN}" "${PROJECT_API_ENDPOINT}/jobs/${ASSET_JOB_ID}/artifacts" > "${DEPLOY_DIR}/assets.zip"

# Unzip artifacts
unzip -q "${DEPLOY_DIR}/assets.zip" -d "${DEPLOY_DIR}"

# Run pre deployment tasks
sudo -n -u www-data php bin/console drenso:deployer:pre

pre_offline_hook

# Put the website on updating
cp deploy/controllers/update.php public/index.php
touch ${DEPLOY_INDICATOR}

# Stop the systemd services
for service in "${SYSTEMD_SERVICES[@]}"; do
  echo "Stopping ${service}"
  sudo -n systemctl stop "${service}"
done

# Stop the messenger queues
for queue in "${MESSENGER_QUEUES[@]}"; do
  echo "Stopping ${SYSTEMD_MESSENGER_BASENAME}@${queue}"
  sudo -n systemctl stop "${SYSTEMD_MESSENGER_BASENAME}@${queue}"
done

# Stop running workers
if [[ "${STOP_RUNNING_MESSENGER_WORKERS}" = true ]] ; then
  sudo -n -u www-data bin/console messenger:stop-workers
fi

# Pull the new data
if [[ "${HAS_GIT_SUBMODULES}" = true ]] ; then
  git submodule init
  git submodule sync
fi
git pull
if [[ "${HAS_GIT_SUBMODULES}" = true ]] ; then
  git submodule update --recursive
fi

# Set the current git hash in the local env
COMMIT_HASH=$(git rev-parse --short=8 HEAD)
touch -a .env.local # Make sure the file exists
if grep -xqiE "^COMMIT_HASH=[0-9a-z]+$" .env.local; then
  sed -i -E "s/^COMMIT_HASH=([0-9a-z]+)$/COMMIT_HASH=${COMMIT_HASH}/i" .env.local
else
  echo "COMMIT_HASH=${COMMIT_HASH}" >> .env.local
fi

# Sync assets to their destination
for i in "${ASSET_PATHS[@]}"; do
  if [[ "${REPLACE_ASSETS}" = true ]] ; then
    mv "${i}" "${DEPLOY_DIR}/${i}.old"
    mv "${DEPLOY_DIR}/${i}" "${i}"
  else
    find "${i}" -type f -mtime +120 \( -name "*.js" -o -name "*.js.map" -o -name "*.css" -o -name "*.css.map" -o -name "*.LICENSE.txt" \) -delete
    rsync -a "${DEPLOY_DIR}/${i}/" "${i}"
  fi
done

# Install vendors (without scripts) and dump the optimized autoload files
composer install --no-dev --no-scripts --no-progress
composer dump-autoload --no-dev --classmap-authoritative

# Rebuild environment file
composer symfony:dump-env

# Clear cache
sudo -n -u www-data php bin/console cache:clear
sudo -n -u www-data php bin/console cache:pool:clear --all
sudo -n -u www-data php bin/console cache:pool:prune

# Install the assets from the used bundles
sudo -n -u www-data php bin/console assets:install --symlink --relative

# Execute migrations
sudo -n -u www-data php bin/console doctrine:migrations:migrate -n -vv --query-time

# Run post deployment tasks
sudo -n -u www-data php bin/console drenso:deployer:post

if [[ "${HAS_LATEX_PODMAN_SERVICE}" = true ]] ; then
  # Configure ACLs for the podman proxy user
  sudo -n -u www-data php bin/console bobv:latex:configure-proxy-acls --output-only | xargs -L 1 -t sudo -n -u root

  # Install the latest podman proxy and restart it
  sudo -n systemctl start bobv-latex-podman-proxy-installer
  sudo -n systemctl restart bobv-latex-podman-proxy
fi

pre_restore_hook

# Restore frontend controller
git checkout public/index.php
rm ${DEPLOY_INDICATOR}

if [[ "${RUN_BACK_ONLINE}" = true ]] ; then
  # Run back online deployment tasks
  sudo -n -u www-data php bin/console drenso:deployer:back-online
fi

# Start the messenger queues
for queue in "${MESSENGER_QUEUES[@]}"; do
  echo "Starting ${SYSTEMD_MESSENGER_BASENAME}@${queue}"
  sudo -n systemctl start "${SYSTEMD_MESSENGER_BASENAME}@${queue}"
done

# Start the systemd services
for service in "${SYSTEMD_SERVICES[@]}"; do
  echo "Starting ${service}"
  sudo -n systemctl start "${service}"
done

if [[ "${HAS_LATEX_PODMAN_SERVICE}" = true ]] ; then
  # Pull latest pdflatex image and clear old images
  sudo -n -u ${LATEX_PODMAN_USER} podman pull registry.drenso.dev/open/docker-images/pdflatex:latest
  sudo -n -u ${LATEX_PODMAN_USER} podman image prune -f
fi

pre_remove_deploy_dir_hook

# Remove deployment artifacts
echo "Clearing deployment directory ${DEPLOY_DIR}"
rm -rf ${DEPLOY_DIR}
