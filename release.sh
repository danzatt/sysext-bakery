#!/bin/bash
#
# Ensure parity of Bakery releases and all extensions / release versions in release_build_versions.txt.
#
# Note that only new releases will be published; existing ones removed from release_build_versions.txt
#   will not be un-published.

set -euo pipefail
cd "$(dirname "$0")"
source "lib/libbakery.sh"

output="${GITHUB_OUTPUT:-release-tag.txt}"

rm -f *.raw SHA256SUMS.* SHA256SUMS *.conf Release.md

extension="${1%:*}"
version="${1#*:}"

function out() {
  echo "${@:-}" | tee -a Release.md
}
# --

out ""
out "New ${extension} extension release ${version}"
out ""
out "Built $(date --rfc-3339 seconds)"

for arch in x86-64 arm64; do
  target="${extension}-${version}-${arch}"
  out "## \`${target}.raw\`"
  ./bakery.sh create "${extension}" "${version}" --format erofs --arch "${arch}" --sysupdate true --output-file "${target}" 2>&1 \
    | tee "${extension}-${version}-${arch}-build.log"
  cat SHA256SUMS."${extension}" >> SHA256SUMS
done

out "## SHA256SUMS"
out '```'
cat SHA256SUMS >> Release.md
out '```'

echo "tag=${extension}-${version}" >> "${output}"

git tag "${extension}-${version}" --force
git push origin "${extension}-${version}" --force
