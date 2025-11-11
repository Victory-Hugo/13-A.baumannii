#!/usr/bin/env bash

set -euo pipefail

# Move the contents of two assembly folders into the merge folder while keeping structure.

SOURCES=(
	"/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Origin"
	"/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Sequence"
)
DEST="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_merge"

if ! command -v rsync >/dev/null 2>&1; then
	echo "rsync command not found; please install rsync before running this script." >&2
	exit 1
fi

if [[ ! -d "$DEST" ]]; then
	echo "Destination directory not found: $DEST" >&2
	exit 1
fi

for src in "${SOURCES[@]}"; do
	if [[ ! -d "$src" ]]; then
		echo "Source directory not found: $src" >&2
		exit 1
	fi
done

for src in "${SOURCES[@]}"; do
	echo "Merging from $src to $DEST"
	rsync -a --remove-source-files "$src"/ "$DEST"/
	find "$src" -type d -empty -delete
done

echo "Merge complete."
