#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 blender-web contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# One-time bootstrap: blobless clone of Blender at the pin. Skips lib/* submodules
# (native prebuilts — not used by the wasm path; deps come from the build_environment superbuild).
set -euo pipefail
# Skip smudge during clone/checkout: blender.git carries LFS pointers under
# assets/ whose objects do not exist on the LFS server (404s abort any
# checkout that smudges the whole tree). The wasm build only needs
# release/datafiles, fetched explicitly below via `git lfs pull --include`
# (git lfs checkout writes files directly, unaffected by the skip).
export GIT_LFS_SKIP_SMUDGE=1
cd "$(dirname "$0")/.."
PIN_COMMIT="fbe6228777e7"
PIN_BRANCH="blender-v5.2-release"
if [ -d upstream/.git ]; then echo "upstream exists; skipping clone"; else
  git clone --filter=blob:none --branch "$PIN_BRANCH" https://github.com/blender/blender.git upstream
fi
cd upstream
git checkout --detach "$PIN_COMMIT" 2>/dev/null || { git fetch origin "$PIN_BRANCH"; git checkout --detach "$PIN_COMMIT"; }
ACTUAL=$(git rev-parse --short=12 HEAD)
echo "pinned at: $ACTUAL (want ${PIN_COMMIT})"
case "$ACTUAL" in "${PIN_COMMIT}"*) echo "PIN OK";; *) echo "PIN MISMATCH — investigate before proceeding" ;; esac
cd ..
git -C upstream lfs pull --include "release/datafiles/*"
du -sh upstream 2>/dev/null
echo "bootstrap done $(date -u +%FT%TZ)" > scripts/bootstrap.done
