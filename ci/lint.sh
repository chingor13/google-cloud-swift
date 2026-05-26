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

echo "--- SWIFT VERSION ---"
swift --version
echo "--- VERSIONS ---"

errors=0
count=0

# macOS ships with Bash 3.x, which does not support readfile. Use a plain
# assignment as a workaround, and set IFS to avoid breaking on spaces.
IFS=$'\n'
packages=($(git ls-files -- '*Package.swift' | xargs -I{} dirname {} | sort))
unset IFS
for dir in "${packages[@]}"; do
    [[ -f "${dir}/Package.swift" ]] || continue
    count=$((count + 1))

    echo "--- Linting ${dir} ---"

    # For local packages, we run swift-format directly on the Sources and Tests directories
    # to avoid the SPM plugin forcefully feeding the generated Rust bridge files.
    if swift run swift-format lint -r "${dir}/Sources" "${dir}/Tests"; then
        echo "✓ ${dir} passed"
    else
        echo "✗ ${dir} failed" >&2
        errors=$((errors + 1))
    fi
done

echo ""
echo "${count} local package(s) linted, ${errors} failure(s)."

if [[ ${errors} -gt 0 ]]; then
    exit 1
fi
