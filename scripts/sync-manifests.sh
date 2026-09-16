#!/usr/bin/env bash
# Sync Scoop manifests in bucket/ from each app's latest GitHub Release.
# Requires: bash, curl, jq, sha256sum (or shasum), python3 (for JSON write).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUCKET="$ROOT/bucket"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# hash_for FILE CHECKSUMS_PATH — resolve sha256 for an asset name from a checksums file.
hash_for() {
  local file="$1"
  local sums="$2"
  # Support both "HASH  file" and "HASH *file" / "HASH file"
  awk -v f="$file" '
    $2 == f || $2 == ("*" f) || $2 == ("./" f) { print $1; exit }
  ' "$sums"
}

sync_ship() {
  local repo="heyoungai/ship"
  local tag version dir sums h64 h_arm
  tag="$(gh release view -R "$repo" --json tagName -q .tagName)"
  version="${tag#v}"
  dir="$TMP/ship"
  mkdir -p "$dir"
  gh release download "$tag" -R "$repo" -D "$dir" -p "checksums.txt" -p "ship-windows-*.exe"
  sums="$dir/checksums.txt"
  # Prefer release checksums file; fall back to local hash if missing lines.
  if [[ ! -f "$sums" ]]; then
    (cd "$dir" && sha256sum ship-windows-*.exe > checksums.txt)
    sums="$dir/checksums.txt"
  fi
  h64="$(hash_for "ship-windows-amd64.exe" "$sums")"
  h_arm="$(hash_for "ship-windows-arm64.exe" "$sums")"
  if [[ -z "$h64" || -z "$h_arm" ]]; then
    echo "error: missing hashes for ship windows assets" >&2
    cat "$sums" >&2 || true
    return 1
  fi

  python3 - "$BUCKET/ship.json" "$version" "$h64" "$h_arm" <<'PY'
import json, sys
path, version, h64, h_arm = sys.argv[1:5]
data = {
    "version": version,
    "description": "Docker image build, push and remote deploy CLI",
    "homepage": "https://github.com/heyoungai/ship",
    "license": "Apache-2.0",
    "architecture": {
        "64bit": {
            "url": f"https://github.com/heyoungai/ship/releases/download/v{version}/ship-windows-amd64.exe#/ship.exe",
            "hash": h64,
        },
        "arm64": {
            "url": f"https://github.com/heyoungai/ship/releases/download/v{version}/ship-windows-arm64.exe#/ship-arm64.exe",
            "hash": h_arm,
        },
    },
    "bin": "ship.exe",
    "checkver": {"github": "https://github.com/heyoungai/ship"},
    "autoupdate": {
        "architecture": {
            "64bit": {
                "url": "https://github.com/heyoungai/ship/releases/download/v$version/ship-windows-amd64.exe#/ship.exe"
            },
            "arm64": {
                "url": "https://github.com/heyoungai/ship/releases/download/v$version/ship-windows-arm64.exe#/ship-arm64.exe"
            },
        },
        "hash": {
            "url": "https://github.com/heyoungai/ship/releases/download/v$version/checksums.txt"
        },
    },
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=4)
    fh.write("\n")
print(f"ship -> v{version}")
PY
}

sync_code_porter() {
  local repo="star-plan/code-porter"
  local tag version dir sums h64 asset
  # Latest release only (skip tags without a Release).
  if ! tag="$(gh release view -R "$repo" --json tagName -q .tagName 2>/dev/null)"; then
    echo "code-porter: no GitHub Release yet; skip"
    return 0
  fi
  version="${tag#v}"
  dir="$TMP/code-porter"
  mkdir -p "$dir"
  asset="code-porter-windows-amd64.exe"
  if ! gh release download "$tag" -R "$repo" -D "$dir" -p "SHA256SUMS" -p "$asset" 2>/dev/null; then
    echo "code-porter: release $tag missing windows binary or SHA256SUMS; skip"
    return 0
  fi
  sums="$dir/SHA256SUMS"
  if [[ ! -f "$sums" ]]; then
    (cd "$dir" && sha256sum "$asset" > SHA256SUMS)
    sums="$dir/SHA256SUMS"
  fi
  h64="$(hash_for "$asset" "$sums")"
  if [[ -z "$h64" && -f "$dir/$asset" ]]; then
    h64="$(sha256sum "$dir/$asset" | awk '{print $1}')"
  fi
  if [[ -z "$h64" ]]; then
    echo "code-porter: could not resolve hash; skip" >&2
    return 0
  fi

  python3 - "$BUCKET/code-porter.json" "$version" "$h64" <<'PY'
import json, sys
path, version, h64 = sys.argv[1:4]
data = {
    "version": version,
    "description": "Local code archive importer/exporter (git bundle + zip)",
    "homepage": "https://github.com/star-plan/code-porter",
    "license": "Apache-2.0",
    "depends": "git",
    "architecture": {
        "64bit": {
            "url": f"https://github.com/star-plan/code-porter/releases/download/v{version}/code-porter-windows-amd64.exe#/code-porter.exe",
            "hash": h64,
        }
    },
    "bin": "code-porter.exe",
    "checkver": {"github": "https://github.com/star-plan/code-porter"},
    "autoupdate": {
        "architecture": {
            "64bit": {
                "url": "https://github.com/star-plan/code-porter/releases/download/v$version/code-porter-windows-amd64.exe#/code-porter.exe"
            }
        },
        "hash": {
            "url": "https://github.com/star-plan/code-porter/releases/download/v$version/SHA256SUMS"
        },
    },
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=4)
    fh.write("\n")
print(f"code-porter -> v{version}")
PY
}

sync_aiquokka() {
  local repo="star-plan/aiquokka"
  local tag version dir sums h64 h_arm asset64 asset_arm

  # Latest release only (skip tags without a Release).
  if ! tag="$(gh release view -R "$repo" --json tagName -q .tagName 2>/dev/null)"; then
    echo "aiquokka: no GitHub Release yet; skip"
    return 0
  fi

  version="${tag#v}"
  dir="$TMP/aiquokka"
  mkdir -p "$dir"

  asset64="aiquokka-windows-amd64.exe"
  asset_arm="aiquokka-windows-arm64.exe"

  if ! gh release download "$tag" \
      -R "$repo" \
      -D "$dir" \
      -p "SHA256SUMS" \
      -p "$asset64" \
      -p "$asset_arm" 2>/dev/null; then
    echo "aiquokka: release $tag missing Windows binaries or SHA256SUMS; skip"
    return 0
  fi

  sums="$dir/SHA256SUMS"

  if [[ ! -f "$sums" ]]; then
    (cd "$dir" && sha256sum "$asset64" "$asset_arm" > SHA256SUMS)
    sums="$dir/SHA256SUMS"
  fi

  h64="$(hash_for "$asset64" "$sums")"
  h_arm="$(hash_for "$asset_arm" "$sums")"

  if [[ -z "$h64" && -f "$dir/$asset64" ]]; then
    h64="$(sha256sum "$dir/$asset64" | awk '{print $1}')"
  fi

  if [[ -z "$h_arm" && -f "$dir/$asset_arm" ]]; then
    h_arm="$(sha256sum "$dir/$asset_arm" | awk '{print $1}')"
  fi

  if [[ -z "$h64" || -z "$h_arm" ]]; then
    echo "aiquokka: could not resolve Windows hashes; skip" >&2
    return 0
  fi

  python3 - "$BUCKET/aiquokka.json" "$version" "$h64" "$h_arm" <<'PY'
import json, sys

path, version, h64, h_arm = sys.argv[1:5]

data = {
    "version": version,
    "description": "Unified subscription quota monitor for Claude, Codex, Cursor, Grok, and more",
    "homepage": "https://github.com/star-plan/aiquokka",
    "license": "MIT",
    "architecture": {
        "64bit": {
            "url": f"https://github.com/star-plan/aiquokka/releases/download/v{version}/aiquokka-windows-amd64.exe#/aiquokka.exe",
            "hash": h64,
        },
        "arm64": {
            "url": f"https://github.com/star-plan/aiquokka/releases/download/v{version}/aiquokka-windows-arm64.exe#/aiquokka.exe",
            "hash": h_arm,
        },
    },
    "bin": "aiquokka.exe",
    "checkver": {
        "github": "https://github.com/star-plan/aiquokka"
    },
    "autoupdate": {
        "architecture": {
            "64bit": {
                "url": "https://github.com/star-plan/aiquokka/releases/download/v$version/aiquokka-windows-amd64.exe#/aiquokka.exe"
            },
            "arm64": {
                "url": "https://github.com/star-plan/aiquokka/releases/download/v$version/aiquokka-windows-arm64.exe#/aiquokka.exe"
            },
        },
        "hash": {
            "url": "https://github.com/star-plan/aiquokka/releases/download/v$version/SHA256SUMS"
        },
    },
}

with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=4)
    fh.write("\n")

print(f"aiquokka -> v{version}")
PY
}

sync_starblog_publisher() {
  local repo="star-blog/starblog-publisher"
  local tag version dir sums
  local h_aot h_fd h_sc
  local a_aot a_fd a_sc

  if ! tag="$(gh release view -R "$repo" --json tagName -q .tagName 2>/dev/null)"; then
    echo "starblog-publisher: no GitHub Release yet; skip"
    return 0
  fi

  version="${tag#v}"
  dir="$TMP/starblog-publisher"
  mkdir -p "$dir"
  if ! gh release download "$tag" -R "$repo" -D "$dir" -p "SHA256SUMS" 2>/dev/null; then
    echo "starblog-publisher: release $tag has no SHA256SUMS yet; skip"
    return 0
  fi

  sums="$dir/SHA256SUMS"
  a_aot="StarBlogPublisher-windows-aot-${version}.zip"
  a_fd="StarBlogPublisher-windows-framework-dependent-${version}.zip"
  a_sc="StarBlogPublisher-windows-self-contained-${version}.zip"
  h_aot="$(hash_for "$a_aot" "$sums")"
  h_fd="$(hash_for "$a_fd" "$sums")"
  h_sc="$(hash_for "$a_sc" "$sums")"

  if [[ -z "$h_aot" || -z "$h_fd" || -z "$h_sc" ]]; then
    echo "starblog-publisher: incomplete Windows release assets for $tag; skip" >&2
    return 0
  fi

  python3 - "$BUCKET" "$version" "$h_aot" "$h_fd" "$h_sc" <<'PY'
import json, sys

bucket, version, h_aot, h_fd, h_sc = sys.argv[1:6]
repo = "https://github.com/star-blog/starblog-publisher"
base = f"{repo}/releases/download/v{version}"
variants = [
    ("starblog-publisher", "aot", h_aot, "Native AOT (default)", "starblog-publisher"),
    ("starblog-publisher-framework-dependent", "framework-dependent", h_fd,
     "Framework-dependent; requires .NET 10 Runtime", "starblog-publisher-framework-dependent"),
    ("starblog-publisher-self-contained", "self-contained", h_sc,
     "Self-contained (non-AOT)", "starblog-publisher-self-contained"),
]

for package, mode, checksum, note, command in variants:
    asset = f"StarBlogPublisher-windows-{mode}-{version}.zip"
    asset_pattern = f"StarBlogPublisher-windows-{mode}-$version.zip"
    data = {
        "version": version,
        "description": "StarBlog Publisher desktop application",
        "homepage": repo,
        "license": "MIT",
        "notes": note,
        "architecture": {
            "64bit": {
                "url": f"{base}/{asset}",
                "hash": checksum,
            }
        },
        "bin": [["StarBlogPublisher.exe", command]],
        "shortcuts": [["StarBlogPublisher.exe", f"StarBlog Publisher ({note})"]],
        "checkver": {"github": repo},
        "autoupdate": {
            "architecture": {
                "64bit": {
                    "url": f"{repo}/releases/download/v$version/{asset_pattern}"
                }
            },
            "hash": {
                "url": f"{repo}/releases/download/v$version/SHA256SUMS",
                "regex": f"$sha256\\s+\\*?StarBlogPublisher-windows-{mode}-$version\\.zip",
            },
        },
    }
    with open(f"{bucket}/{package}.json", "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=4)
        fh.write("\n")
    print(f"{package} -> v{version}")
PY
}

main() {
  mkdir -p "$BUCKET"
  sync_ship
  sync_code_porter
  sync_aiquokka
  sync_starblog_publisher
  echo "sync complete"
}

main "$@"
