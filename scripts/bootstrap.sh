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
# LFS datafiles pull. GitHub's blender.git LFS is missing a handful of objects
# (known 404s under release/datafiles/assets and others), and a single missing
# object aborts the whole `git lfs pull`. Pull tolerantly, then try Blender's
# canonical Gitea remote for whatever is still unresolved, and finally REPORT the
# remaining pointer files instead of failing the bootstrap (the build preloads
# datafiles wholesale; if a genuinely required file is missing the build itself
# is the right place to surface it).
git -C upstream config lfs.fetchinclude "release/datafiles/*"
git -C upstream lfs pull || echo "bootstrap: lfs pull incomplete (expected on GitHub mirror); probing gaps"
GAPS=$(cd upstream && { find release/datafiles -type f -size -2k 2>/dev/null | while read -r f; do
  if head -c 30 "$f" 2>/dev/null | grep -q "^version https://git-lfs"; then echo "$f"; fi
done; true; })
if [ -n "$GAPS" ]; then
  echo "bootstrap: $(echo "$GAPS" | wc -l) datafiles still unresolved from GitHub LFS; trying projects.blender.org"
  git -C upstream remote add blender https://projects.blender.org/blender/blender.git 2>/dev/null || true
  git -C upstream fetch --no-tags blender "$PIN_BRANCH" \
    && git -C upstream lfs fetch blender "$PIN_BRANCH" \
    && git -C upstream lfs checkout \
    || echo "bootstrap: projects.blender.org fallback incomplete"
  GAPS=$(cd upstream && { find release/datafiles -type f -size -2k 2>/dev/null | while read -r f; do
    if head -c 30 "$f" 2>/dev/null | grep -q "^version https://git-lfs"; then echo "$f"; fi
  done; true; })
fi
if [ -n "$GAPS" ]; then
  echo "bootstrap: WARNING - datafiles still missing LFS objects:"
  echo "$GAPS"
fi
du -sh upstream 2>/dev/null
echo "bootstrap done $(date -u +%FT%TZ)" > scripts/bootstrap.done
