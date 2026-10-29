#!/usr/bin/env bash
# Daily snapshot of release download counts across the product family.
# Uses the public releases API; GITHUB_TOKEN (optional, local runs work
# without it) only raises the rate limit — repos are public.
#
# A repo whose API call fails or returns a non-array body (renamed repo,
# transient API error) is skipped and recorded under "skipped" in the
# snapshot — one bad repo must not kill the daily run. Renames are
# followed transparently (-L), so a renamed repo keeps reporting under
# the name listed here until the list is updated.
set -euo pipefail

ORG=turlamai
REPOS="fulcrum taskly payback threadly movebit syncpilot booklight podlens autarx keyward regexmate keepsake gptp-studio flashpilot moonbeam hackdigest pitboard yinwang-archive"

date=$(date -u +%F)
mkdir -p data
auth=(-H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && auth+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
parts=()
skipped=()

for r in $REPOS; do
  if ! body=$(curl -sfL --retry 3 "${auth[@]}" \
      "https://api.github.com/repos/${ORG}/${r}/releases?per_page=100"); then
    echo "warn: ${r}: releases API call failed, skipped" >&2
    skipped+=("$r")
    continue
  fi
  if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$body"; then
    echo "warn: ${r}: non-array API response, skipped" >&2
    skipped+=("$r")
    continue
  fi
  if ! out=$(jq -c --arg repo "$r" '
    def versionless: test("[0-9]+\\.[0-9]+") | not;
    { ($repo): {
        total: ([.[].assets[] | select(.name | test("\\.(sha256|sig|asc|sbom|json|txt)$|SHA256SUMS|MANIFEST|NOTICES") | not) | .download_count] | add // 0),
        releases: map({
          tag: .tag_name,
          published: (.published_at // ""),
          prerelease: .prerelease,
          downloads: ([.assets[] | select(.name | test("\\.(sha256|sig|asc|sbom|json|txt)$|SHA256SUMS|MANIFEST|NOTICES") | not) | .download_count] | add // 0),
          assets: [.assets[] | select(.name | test("\\.(sha256|sig|asc|sbom|json|txt)$|SHA256SUMS|MANIFEST|NOTICES") | not) |
            {name: .name, count: .download_count,
             alias: (.name | versionless)}]
        }) }}' <<<"$body"); then
    echo "warn: ${r}: snapshot parsing failed, skipped" >&2
    skipped+=("$r")
    continue
  fi
  parts+=("$out")
done

skipped_json='[]'
if [ "${#skipped[@]}" -gt 0 ]; then
  skipped_json=$(printf '%s\n' "${skipped[@]}" | jq -R . | jq -sc .)
fi
# Feed per-repo objects through a temp file: large payloads break exec
# argument limits if passed as argv (notably MSYS/Windows).
parts_file=$(mktemp)
trap 'rm -f "$parts_file"' EXIT
if [ "${#parts[@]}" -gt 0 ]; then
  printf '%s\n' "${parts[@]}" > "$parts_file"
fi
jq -s --arg date "$date" --argjson skipped "$skipped_json" \
  '{date: $date, repos: (add // {}), skipped: $skipped}' \
  "$parts_file" > "data/${date}.json"

ls data/2*.json | sort | sed 's|.*/||; s|\.json$||' | jq -R . | jq -s . > data/index.json
echo "snapshot written: data/${date}.json ($(wc -c < "data/${date}.json") bytes, skipped: ${#skipped[@]})"
