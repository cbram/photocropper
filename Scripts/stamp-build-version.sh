#!/bin/sh
#
# stamp-build-version.sh
# PhotoCropper
#
# Xcode run script phase: stamps the processed Info.plist of the build product
# (never the source tree) with
#   CFBundleVersion = number of commits on HEAD (git rev-list --count HEAD)
#   GitCommit       = short commit hash, suffixed with "+dirty" if the working tree has changes
# Without git or outside a repository the build still succeeds with fallback values.

set -eu

FALLBACK_BUILD_NUMBER="0"
FALLBACK_COMMIT="unknown"
DIRTY_SUFFIX="+dirty"

plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
plist_buddy="/usr/libexec/PlistBuddy"

build_number="$FALLBACK_BUILD_NUMBER"
commit="$FALLBACK_COMMIT"

if git -C "$SRCROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    build_number="$(git -C "$SRCROOT" rev-list --count HEAD)"
    commit="$(git -C "$SRCROOT" rev-parse --short HEAD)"
    if [ -n "$(git -C "$SRCROOT" status --porcelain)" ]; then
        commit="${commit}${DIRTY_SUFFIX}"
    fi
else
    echo "warning: no git repository found, using build number ${FALLBACK_BUILD_NUMBER} and commit '${FALLBACK_COMMIT}'"
fi

"$plist_buddy" -c "Set :CFBundleVersion ${build_number}" "$plist"
# Set fails if the key does not exist yet, then add it
"$plist_buddy" -c "Set :GitCommit ${commit}" "$plist" 2>/dev/null \
    || "$plist_buddy" -c "Add :GitCommit string ${commit}" "$plist"

echo "Stamped ${plist}: CFBundleVersion=${build_number}, GitCommit=${commit}"
