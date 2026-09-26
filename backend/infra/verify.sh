#!/usr/bin/env bash
set -euo pipefail
GCLOUD="${GCLOUD:-gcloud}"
PROJECT=cove-mail-20260922
REGION=us-east1
: "${COVE_SYNC_ENV_FILE:?Set COVE_SYNC_ENV_FILE to the deployment environment YAML}"
: "${COVE_DB_SECRET_VERSION:?Pin the restricted database secret version}"
IMAGE=$("$GCLOUD" run services describe cove-sync-api --project="$PROJECT" --region="$REGION" --format='value(spec.template.spec.containers[0].image)')
"$GCLOUD" run jobs deploy cove-sync-storage-check --image="$IMAGE" --project="$PROJECT" --region="$REGION" \
 --service-account="cove-sync-api@$PROJECT.iam.gserviceaccount.com" --command=node --args=src/verify-storage.js \
 --tasks=1 --max-retries=0 --task-timeout=120 --cpu=1 --memory=512Mi \
 --env-vars-file="$COVE_SYNC_ENV_FILE" --set-secrets="DATABASE_URL=cove-sync-database-url:$COVE_DB_SECRET_VERSION" --quiet
"$GCLOUD" run jobs execute cove-sync-storage-check --project="$PROJECT" --region="$REGION" --wait --quiet
