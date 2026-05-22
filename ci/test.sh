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
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${REPO_ROOT}/packages"

errors=0
packages=0

echo "--- SWIFT VERSION ---"
swift --version
echo "--- VERSIONS ---"

echo "--- Testing Root Package ---"
pushd "${REPO_ROOT}" >/dev/null
if swift test; then
    echo "✓ Root Package tests passed"
else
    echo "✗ Root Package tests failed" >&2
    errors=$((errors + 1))
fi
popd >/dev/null

if [[ -d "${PACKAGES_DIR}" ]]; then
    for package_dir in "${PACKAGES_DIR}"/*/; do
        [[ -f "${package_dir}/Package.swift" ]] || continue

        package_name="$(basename "${package_dir}")"
        packages=$((packages + 1))
        echo "--- Testing ${package_name} ---"

        pushd "${package_dir}" >/dev/null
        if swift test; then
            echo "✓ ${package_name} passed"
        else
            echo "✗ ${package_name} failed" >&2
            errors=$((errors + 1))
        fi
        popd >/dev/null
    done
fi

echo ""
echo "Root package + ${packages} local package(s) tested, ${errors} failure(s)."

if [[ ${errors} -gt 0 ]]; then
    exit 1
fi
