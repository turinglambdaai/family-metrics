#!/usr/bin/env bash
# Daily snapshot of release download counts across the product family.
# Uses the public releases API; GITHUB_TOKEN (optional, local runs work
# without it) only raises the rate limit — repos are public.
set -euo pipefail

ORG=turinglambdaai
REPOS="fulcrum taskly payback threadly movebit syncpilot brainfuel pdfgist podlens autarx benchpilot keyward regexmate keepsake gptp-studio flashpilot moonbeam hackdigest pitboard yinwangdl"

date=$(date -u +%F)
mkdir -p data
auth=(-H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && auth+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

for r in $REPOS; do
  curl -sf --retry 3 "${auth[@]}" \
    "https://api.github.com/repos/${ORG}/${r}/releases?per_page=100" \
  | jq -c --arg repo "$r" '
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
        }) }}'
done | jq -s --arg date "$date" '{date: $date, repos: (add // {})}' > "data/${date}.json"

ls data/2*.json | sort | sed 's|.*/||; s|\.json$||' | jq -R . | jq -s . > data/index.json
echo "snapshot written: data/${date}.json ($(wc -c < "data/${date}.json") bytes)"
