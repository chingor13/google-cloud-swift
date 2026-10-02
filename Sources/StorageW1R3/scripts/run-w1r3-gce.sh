#!/usr/bin/env bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: run-w1r3-gce.sh [OPTIONS]

Deploys and runs the Cloud Storage W1R3 benchmark on a Google Compute Engine (GCE) VM,
uploads performance metrics to Cloud Storage and BigQuery, and automatically tears down
the VM to prevent unnecessary compute costs.

Options:
  --project PROJECT_ID         GCP project ID (default: current gcloud project)
  --zone ZONE                  GCE zone (default: us-central1-a)
  --region REGION              GCP region (default: derived from zone)
  --machine-type TYPE          GCE machine type (default: c2d-standard-8)
  --bucket BUCKET_NAME         GCS test bucket name (default: w1r3-<PROJECT>-<REGION>)
  --results-bucket BUCKET_NAME GCS bucket for results and logs (default: same as test bucket)
  --bq-dataset DATASET         BigQuery dataset for benchmark results (default: w1r3)
  --bq-table TABLE             BigQuery table name (default: swift_<RUN_ID>)
  --git-repo URL               Git repository URL to clone on the VM
                               (default: current git origin or https://github.com/googleapis/google-cloud-swift.git)
  --git-ref REF                Git commit, branch, or tag to checkout (default: current git commit or main)
  --stage-local                Stage current local repository directory to GCS for the VM to build,
                               enabling benchmarking of uncommitted or unpushed changes.
  --service-account EMAIL      Service account for the GCE VM (default: Compute Engine default SA)
  --task-count N               Number of concurrent benchmark tasks (default: 4)
  --iterations N               Number of iterations per task (default: 100)
  --min-object-size SIZE       Minimum object size, e.g. 0, 128KiB, 1MiB (default: 0)
  --max-object-size SIZE       Maximum object size, e.g. 128KiB, 1MiB, 16MiB (default: 128KiB)
  --read-count N               Number of reads per uploaded object (default: 3)
  --client-count N             Number of Storage clients (default: 1)
  --crc32c MODE                CRC32C mode: always, random, never (default: always)
  --extra-args "ARGS"          Extra arguments passed directly to StorageW1R3Benchmark
  --no-wait / --async          Launch the VM and return immediately without tailing logs
  --keep-vm / --no-teardown    Do not delete the VM after the benchmark completes
  -h, --help                   Show this help message and exit

Examples:
  # Quick smoke test with default settings:
  ./Sources/StorageW1R3/scripts/run-w1r3-gce.sh --task-count 2 --iterations 10

  # High-throughput benchmark with 16MiB objects on c2d-standard-16:
  ./Sources/StorageW1R3/scripts/run-w1r3-gce.sh \
    --machine-type c2d-standard-16 \
    --task-count 16 \
    --iterations 200 \
    --min-object-size 16MiB \
    --max-object-size 16MiB

  # Benchmark local unpushed changes:
  ./Sources/StorageW1R3/scripts/run-w1r3-gce.sh --stage-local --task-count 4 --iterations 50
EOF
  exit 0
}

# Default configurations
PROJECT_ID=""
ZONE="us-central1-a"
REGION=""
MACHINE_TYPE="c2d-standard-8"
BUCKET_NAME=""
RESULTS_BUCKET=""
BQ_DATASET="w1r3"
BQ_TABLE=""
GIT_REPO=""
GIT_REF=""
STAGE_LOCAL=false
SERVICE_ACCOUNT=""
TASK_COUNT=4
ITERATIONS=100
MIN_OBJECT_SIZE="0"
MAX_OBJECT_SIZE="128KiB"
READ_COUNT=3
CLIENT_COUNT=1
CRC32C="always"
EXTRA_ARGS=""
WAIT_FOR_COMPLETION=true
AUTO_TEARDOWN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --zone) ZONE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --machine-type) MACHINE_TYPE="$2"; shift 2 ;;
    --bucket) BUCKET_NAME="$2"; shift 2 ;;
    --results-bucket) RESULTS_BUCKET="$2"; shift 2 ;;
    --bq-dataset) BQ_DATASET="$2"; shift 2 ;;
    --bq-table) BQ_TABLE="$2"; shift 2 ;;
    --git-repo) GIT_REPO="$2"; shift 2 ;;
    --git-ref) GIT_REF="$2"; shift 2 ;;
    --stage-local) STAGE_LOCAL=true; shift 1 ;;
    --service-account) SERVICE_ACCOUNT="$2"; shift 2 ;;
    --task-count) TASK_COUNT="$2"; shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --min-object-size) MIN_OBJECT_SIZE="$2"; shift 2 ;;
    --max-object-size) MAX_OBJECT_SIZE="$2"; shift 2 ;;
    --read-count) READ_COUNT="$2"; shift 2 ;;
    --client-count) CLIENT_COUNT="$2"; shift 2 ;;
    --crc32c) CRC32C="$2"; shift 2 ;;
    --extra-args) EXTRA_ARGS="$2"; shift 2 ;;
    --no-wait|--async) WAIT_FOR_COMPLETION=false; shift 1 ;;
    --keep-vm|--no-teardown) AUTO_TEARDOWN=false; shift 1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; echo "Run with --help for usage." >&2; exit 1 ;;
  esac
done

# Prerequisite checks
if ! command -v gcloud &>/dev/null; then
  echo "ERROR: 'gcloud' CLI is required but not found in PATH." >&2
  exit 1
fi

if ! command -v bq &>/dev/null; then
  echo "WARNING: 'bq' CLI not found. BigQuery loading might be skipped if not available on VM." >&2
fi

# Detect project
if [[ -z "${PROJECT_ID}" ]]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
  if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
    echo "ERROR: GCP project is not configured in gcloud and was not specified via --project." >&2
    exit 1
  fi
fi

# Derive region from zone if unset (e.g. us-central1-a -> us-central1)
if [[ -z "${REGION}" ]]; then
  REGION="${ZONE%-*}"
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2 2>/dev/null || date +%s)"
INSTANCE_NAME="w1r3-${RUN_ID}"

if [[ -z "${BUCKET_NAME}" ]]; then
  BUCKET_NAME="w1r3-${PROJECT_ID}-${REGION}"
fi

if [[ -z "${RESULTS_BUCKET}" ]]; then
  RESULTS_BUCKET="${BUCKET_NAME}"
fi

if [[ -z "${BQ_TABLE}" ]]; then
  # BigQuery table names cannot contain hyphens
  BQ_TABLE="swift_${RUN_ID//-/_}"
fi

# Detect Git repo and ref if not specified
if [[ -z "${GIT_REPO}" ]]; then
  GIT_REPO=$(git config --get remote.origin.url 2>/dev/null || echo "https://github.com/googleapis/google-cloud-swift.git")
  # Convert git@github.com:org/repo.git to https://github.com/org/repo.git for VM access
  if [[ "${GIT_REPO}" =~ ^git@github\.com:(.*)$ ]]; then
    GIT_REPO="https://github.com/${BASH_REMATCH[1]}"
  fi
fi

if [[ -z "${GIT_REF}" ]]; then
  GIT_REF=$(git rev-parse HEAD 2>/dev/null || echo "main")
fi

echo "=========================================================="
echo "Google Cloud Storage W1R3 Benchmark - GCE Deployment"
echo "=========================================================="
echo "Project:         ${PROJECT_ID}"
echo "Zone:            ${ZONE} (Region: ${REGION})"
echo "Machine Type:    ${MACHINE_TYPE}"
echo "Instance:        ${INSTANCE_NAME}"
echo "Test Bucket:     gs://${BUCKET_NAME}"
echo "Results Bucket:  gs://${RESULTS_BUCKET}"
echo "BigQuery Target: ${PROJECT_ID}:${BQ_DATASET}.${BQ_TABLE}"
echo "Git Source:      ${GIT_REPO} @ ${GIT_REF}"
if [[ "${STAGE_LOCAL}" == "true" ]]; then
  echo "Source Mode:     Staging local working tree"
fi
echo "Benchmark Config: tasks=${TASK_COUNT}, iterations=${ITERATIONS}, size=${MIN_OBJECT_SIZE}..${MAX_OBJECT_SIZE}, reads=${READ_COUNT}, crc32c=${CRC32C}"
echo "Auto-teardown:   ${AUTO_TEARDOWN}"
echo "=========================================================="

# 1. Ensure test bucket exists
echo "Checking test bucket gs://${BUCKET_NAME}..."
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} does not exist. Creating regional bucket with recommended performance settings..."
  LF_FILE="${SCRIPT_DIR}/lf.json"
  gcloud storage buckets create \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --enable-hierarchical-namespace \
    --uniform-bucket-level-access \
    --soft-delete-duration=0s \
    --lifecycle-file="${LF_FILE}" \
    "gs://${BUCKET_NAME}"
  echo "✓ Bucket gs://${BUCKET_NAME} created."
else
  echo "✓ Bucket gs://${BUCKET_NAME} exists."
fi

# Ensure results bucket exists if distinct
if [[ "${RESULTS_BUCKET}" != "${BUCKET_NAME}" ]]; then
  if ! gcloud storage buckets describe "gs://${RESULTS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Creating results bucket gs://${RESULTS_BUCKET}..."
    gcloud storage buckets create \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access \
      "gs://${RESULTS_BUCKET}"
    echo "✓ Results bucket gs://${RESULTS_BUCKET} created."
  fi
fi

# 2. Configure Service Account
if [[ -z "${SERVICE_ACCOUNT}" ]]; then
  PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')
  SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
fi
echo "Using VM Service Account: ${SERVICE_ACCOUNT}"

# Grant storage objectAdmin on the test and results bucket
echo "Ensuring IAM permissions on buckets..."
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/storage.objectAdmin" >/dev/null 2>&1 || true

if [[ "${RESULTS_BUCKET}" != "${BUCKET_NAME}" ]]; then
  gcloud storage buckets add-iam-policy-binding "gs://${RESULTS_BUCKET}" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectAdmin" >/dev/null 2>&1 || true
fi

# Ensure BigQuery dataset exists
if [[ -n "${BQ_DATASET}" ]]; then
  echo "Ensuring BigQuery dataset '${PROJECT_ID}:${BQ_DATASET}' exists..."
  bq show "${PROJECT_ID}:${BQ_DATASET}" >/dev/null 2>&1 || \
    bq mk --project_id="${PROJECT_ID}" --location="${REGION}" --dataset "${PROJECT_ID}:${BQ_DATASET}" >/dev/null 2>&1 || true
fi

# 3. Handle Local Staging if requested
SOURCE_TAR_GCS=""
if [[ "${STAGE_LOCAL}" == "true" ]]; then
  echo "Creating archive of local repository..."
  TEMP_ARCHIVE=$(mktemp /tmp/w1r3-src-XXXXXX.tar.gz)
  # Archive tracked git files plus submodules
  git archive --format=tar.gz -o "${TEMP_ARCHIVE}" HEAD
  SOURCE_TAR_GCS="gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/source.tar.gz"
  echo "Uploading local source archive to ${SOURCE_TAR_GCS}..."
  gcloud storage cp "${TEMP_ARCHIVE}" "${SOURCE_TAR_GCS}"
  rm -f "${TEMP_ARCHIVE}"
fi

# 4. Prepare Metadata attributes
BENCHMARK_ARGS="--task-count ${TASK_COUNT} --iterations ${ITERATIONS} --min-object-size ${MIN_OBJECT_SIZE} --max-object-size ${MAX_OBJECT_SIZE} --read-count ${READ_COUNT} --client-count ${CLIENT_COUNT} --crc32c ${CRC32C}"
if [[ -n "${EXTRA_ARGS}" ]]; then
  BENCHMARK_ARGS="${BENCHMARK_ARGS} ${EXTRA_ARGS}"
fi

METADATA_ENTRIES=(
  "bucket-name=${BUCKET_NAME}"
  "results-bucket=${RESULTS_BUCKET}"
  "run-id=${RUN_ID}"
  "bq-dataset=${BQ_DATASET}"
  "bq-table=${BQ_TABLE}"
  "git-repo=${GIT_REPO}"
  "git-ref=${GIT_REF}"
  "benchmark-args=${BENCHMARK_ARGS}"
  "auto-teardown=${AUTO_TEARDOWN}"
)
if [[ -n "${SOURCE_TAR_GCS}" ]]; then
  METADATA_ENTRIES+=("source-tar-gcs=${SOURCE_TAR_GCS}")
fi

# Join metadata entries with comma
IFS=',' METADATA_STR="${METADATA_ENTRIES[*]}"

# 5. Launch GCE Instance
STARTUP_SCRIPT="${SCRIPT_DIR}/vm-startup.sh"
if [[ ! -f "${STARTUP_SCRIPT}" ]]; then
  echo "ERROR: Startup script not found at ${STARTUP_SCRIPT}" >&2
  exit 1
fi

echo "Creating GCE VM instance '${INSTANCE_NAME}' in ${ZONE}..."
gcloud compute instances create "${INSTANCE_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --network-tier=PREMIUM \
  --scopes=cloud-platform \
  --service-account="${SERVICE_ACCOUNT}" \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-ssd \
  --metadata="${METADATA_STR}" \
  --metadata-from-file="startup-script=${STARTUP_SCRIPT}" \
  --quiet

echo "✓ VM '${INSTANCE_NAME}' created successfully."

if [[ "${WAIT_FOR_COMPLETION}" != "true" ]]; then
  echo ""
  echo "Benchmark launched asynchronously!"
  echo "To view execution logs in real-time, run:"
  echo "  gcloud compute instances tail-serial-port-output ${INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID}"
  echo ""
  echo "Results will be available at:"
  echo "  Cloud Storage: gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/"
  echo "  BigQuery:      ${PROJECT_ID}:${BQ_DATASET}.${BQ_TABLE}"
  exit 0
fi

# 6. Stream logs and wait for completion
echo ""
echo "Streaming VM console output (Ctrl+C will detach without canceling the benchmark)..."
echo "----------------------------------------------------------"

# Tail serial port output until instance terminates/shuts down
gcloud compute instances tail-serial-port-output "${INSTANCE_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" || true

echo "----------------------------------------------------------"
echo "VM execution completed or detached."

# Check status in GCS
STATUS_FILE="gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/STATUS"
RUN_STATUS="UNKNOWN"
if gcloud storage objects describe "${STATUS_FILE}" >/dev/null 2>&1; then
  RUN_STATUS=$(gcloud storage cat "${STATUS_FILE}" 2>/dev/null || echo "UNKNOWN")
fi

echo "Run Status: ${RUN_STATUS}"

# 7. Post-run Teardown check
if [[ "${AUTO_TEARDOWN}" == "true" ]]; then
  echo "Verifying VM deletion..."
  if gcloud compute instances describe "${INSTANCE_NAME}" --zone="${ZONE}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Deleting VM '${INSTANCE_NAME}'..."
    gcloud compute instances delete "${INSTANCE_NAME}" \
      --zone="${ZONE}" \
      --project="${PROJECT_ID}" \
      --quiet || true
    echo "✓ VM deleted."
  else
    echo "✓ VM was automatically deleted by the startup script."
  fi
fi

# 8. Summary and Query Instructions
echo ""
echo "=========================================================="
echo "Benchmark Summary"
echo "=========================================================="
echo "Run ID:          ${RUN_ID}"
echo "Status:          ${RUN_STATUS}"
echo "GCS Artifacts:   gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/"
echo "  - Results:     gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/results.csv"
echo "  - Log:         gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/benchmark.log"
echo "  - Metadata:    gs://${RESULTS_BUCKET}/w1r3/${RUN_ID}/metadata.json"
echo "BigQuery Table:  ${PROJECT_ID}:${BQ_DATASET}.${BQ_TABLE}"
echo ""
echo "Sample BigQuery Analysis Query:"
cat <<EOF
SELECT
  Operation,
  COUNT(*) as sample_count,
  ROUND(AVG(TransferSize / (1024 * 1024)), 2) as avg_size_mib,
  ROUND(AVG((TransferSize * 8.0) / (ElapsedMicroseconds)), 2) as avg_throughput_mbps,
  APPROX_QUANTILES(ElapsedMicroseconds / 1000.0, 100)[OFFSET(50)] as p50_ms,
  APPROX_QUANTILES(ElapsedMicroseconds / 1000.0, 100)[OFFSET(90)] as p90_ms,
  APPROX_QUANTILES(ElapsedMicroseconds / 1000.0, 100)[OFFSET(99)] as p99_ms
FROM \`${PROJECT_ID}.${BQ_DATASET}.${BQ_TABLE}\`
WHERE Result = 'OK'
GROUP BY Operation
ORDER BY Operation;
EOF
echo "=========================================================="
