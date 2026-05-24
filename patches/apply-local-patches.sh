#!/bin/bash -ex

MODE="${1:-quilt}"
PATCHES_SRC_DIR="scale-build-patches"
DEBIAN_PATCHES_DIR="debian/patches"

# Nothing to do if no local patches directory was provided
if [ ! -d "$PATCHES_SRC_DIR" ]
then
    # echo "No ${PATCHES_SRC_DIR}/ directory found, skipping."
    exit 0
fi

# Collect patch files, skip quietly if none present
if [ -z $(find "$PATCHES_SRC_DIR" -name "*.patch") ]; then
    # echo "No .patch files found in ${PATCHES_SRC_DIR}/, skipping."
    exit 0
fi

if [ "$MODE" = "direct" ]
then
    while IFS= read -r patch_src
    do
        echo "Applying patch ${patch_src} directly."
        patch -p1 < "$patch_src"
        echo "Patch ${patch_src} applied."
    done < <(find "$PATCHES_SRC_DIR" -name "*.patch" | sort)
else
    # Ensure debian/patches and its series file exist
    mkdir -p "$DEBIAN_PATCHES_DIR"
    touch "${DEBIAN_PATCHES_DIR}/series"

    while IFS= read -r patch_src
    do
        # Relative path within scale-build-patches/ e.g. "subdir/0001-foo.patch"
        patch_rel="${patch_src#${PATCHES_SRC_DIR}/}"
        patch_dst="${DEBIAN_PATCHES_DIR}/${patch_rel}"
        patch_dst_dir="$(dirname "$patch_dst")"

        # Check if patch already exists in debian/patches/
        if [ -f "$patch_dst" ]; then
            if diff -q "$patch_src" "$patch_dst" > /dev/null 2>&1; then
                # Identical  already present, nothing to do for this file
                echo "Already present, skipping: ${patch_rel}"
            else
                # Exists but differs  refuse to overwrite, fail loudly
                echo "ERROR: ${patch_dst} already exists and differs from ${patch_src}." >&2
                echo "Resolve the conflict manually before building." >&2
                exit 1
            fi
        else
            # Does not exist yet  create directory structure and copy
            mkdir -p "$patch_dst_dir"
            cp --preserve=timestamps "$patch_src" "$patch_dst"
            echo "Copied: ${patch_rel}"
        fi

        # Append to series file only if not already listed
        if grep -qxF "$patch_rel" "${DEBIAN_PATCHES_DIR}/series"; then
            echo "Already in series, skipping: ${patch_rel}"
        else
            echo "$patch_rel" >> "${DEBIAN_PATCHES_DIR}/series"
            echo "Enqueued: ${patch_rel}"
        fi

    done < <(find "$PATCHES_SRC_DIR" -name "*.patch" | sort)

fi

echo "Done. Local patches are integrated."

