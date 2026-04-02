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

# Runs swift-format lint for every local package found under `packages/`.
# New local packages are picked up automatically — no changes to this script
# are required when adding one.
#
# Unfortunately, there are no standard or community tools to do this
# automatically in the Swift ecosystem.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${REPO_ROOT}/packages"

if [[ ! -d "${PACKAGES_DIR}" ]]; then
    echo "No packages/ directory found at ${REPO_ROOT}" >&2
    exit 1
fi

errors=0
packages=0

echo "--- Linting Root Package ---"
if swift package plugin lint-source-code; then
    echo "✓ Root Package passed"
else
    echo "✗ Root Package failed" >&2
    errors=$((errors + 1))
fi

for package_dir in "${PACKAGES_DIR}"/*/; do
    [[ -f "${package_dir}/Package.swift" ]] || continue

    package_name="$(basename "${package_dir}")"
    packages=$((packages + 1))
    echo "--- Linting ${package_name} ---"

    # For local packages, we run swift-format directly on the Sources and Tests directories
    # to avoid the SPM plugin forcefully feeding the generated Rust bridge files.
    if swift run swift-format lint -r "${package_dir}/Sources" "${package_dir}/Tests"; then
        echo "✓ ${package_name} passed"
    else
        echo "✗ ${package_name} failed" >&2
        errors=$((errors + 1))
    fi
done

if [[ ${packages} -eq 0 ]]; then
    echo "No local packages found under ${PACKAGES_DIR}" >&2
    exit 1
fi

echo ""
echo "${packages} package(s) linted, ${errors} failure(s)."

if [[ ${errors} -gt 0 ]]; then
    exit 1
fi
