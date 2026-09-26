#!/usr/bin/env bash
# Cove pilot only. Credentials are never printed or passed as command arguments.
set -euo pipefail
GCLOUD="${GCLOUD:-gcloud}"
PROJECT=cove-mail-20260922
REGION=us-east1
BUCKET=cove-mail-20260922-sync-bodies
SERVICE_ACCOUNT=cove-sync-api@${PROJECT}.iam.gserviceaccount.com
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$GCLOUD" services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com cloudkms.googleapis.com secretmanager.googleapis.com storage.googleapis.com --project="$PROJECT" --quiet
if ! "$GCLOUD" iam service-accounts describe "$SERVICE_ACCOUNT" --project="$PROJECT" >/dev/null 2>&1; then
  "$GCLOUD" iam service-accounts create cove-sync-api --display-name='Cove sync API' --project="$PROJECT" --quiet
fi
if ! "$GCLOUD" kms keyrings describe cove-sync --location="$REGION" --project="$PROJECT" >/dev/null 2>&1; then
  "$GCLOUD" kms keyrings create cove-sync --location="$REGION" --project="$PROJECT" --quiet
fi
if ! "$GCLOUD" kms keys describe account-keys --keyring=cove-sync --location="$REGION" --project="$PROJECT" >/dev/null 2>&1; then
  "$GCLOUD" kms keys create account-keys --purpose=encryption --keyring=cove-sync --location="$REGION" --project="$PROJECT" --quiet
fi
"$GCLOUD" kms keys add-iam-policy-binding account-keys --keyring=cove-sync --location="$REGION" --project="$PROJECT" --member="serviceAccount:$SERVICE_ACCOUNT" --role=roles/cloudkms.cryptoKeyEncrypterDecrypter --quiet >/dev/null
if ! "$GCLOUD" storage buckets describe "gs://$BUCKET" --project="$PROJECT" >/dev/null 2>&1; then
  "$GCLOUD" storage buckets create "gs://$BUCKET" --location="$REGION" --uniform-bucket-level-access --public-access-prevention --project="$PROJECT" --quiet
fi
"$GCLOUD" storage buckets update "gs://$BUCKET" --uniform-bucket-level-access --public-access-prevention --clear-soft-delete --lifecycle-file="$ROOT/infra/body-lifecycle.json" --project="$PROJECT" --quiet
# Runtime can create random immutable ciphertext objects and read/list them, not delete them or change bucket policy.
for role in roles/storage.objectCreator roles/storage.objectViewer; do
  "$GCLOUD" storage buckets add-iam-policy-binding "gs://$BUCKET" --member="serviceAccount:$SERVICE_ACCOUNT" --role="$role" --project="$PROJECT" --quiet >/dev/null
done
if ! "$GCLOUD" secrets describe cove-sync-database-url --project="$PROJECT" >/dev/null 2>&1; then
  "$GCLOUD" secrets create cove-sync-database-url --replication-policy=user-managed --locations="$REGION" --project="$PROJECT" --quiet
fi
"$GCLOUD" secrets add-iam-policy-binding cove-sync-database-url --project="$PROJECT" --member="serviceAccount:$SERVICE_ACCOUNT" --role=roles/secretmanager.secretAccessor --quiet >/dev/null
if ! "$GCLOUD" artifacts repositories describe cove-sync --location="$REGION" --project="$PROJECT" >/dev/null 2>&1; then
  "$GCLOUD" artifacts repositories create cove-sync --repository-format=docker --location="$REGION" --project="$PROJECT" --quiet
fi
printf 'Cove pilot infrastructure provisioned. No mail uploaded. Database secret and API deployment are separate steps.\n'
