#!/bin/bash
# Bulk-ingest a broad, size-capped corpus from the user's real files into the
# SMFS mount (the product ingestion path). Names are prefixed with their origin
# so collisions can't clobber and citations stay legible.
set -u
MOUNT=~/Mnemo/memory
copied=0

copy() { # $1=src $2=prefix
  local src="$1" prefix="$2" base dest
  base=$(basename "$src" | tr ' ' '-' | tr -cd '[:alnum:]._-')
  dest="$MOUNT/${prefix}--${base}"
  [ -e "$dest" ] && return 0
  cp "$src" "$dest" 2>/dev/null && copied=$((copied+1)) && echo "$dest"
}

pick() { # $1=dir $2=find-args... : prints selected files
  local dir="$1"; shift
  find "$dir" -type f "$@" \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" \
    -not -path "*/.build/*" -not -name ".*" 2>/dev/null
}

# 1. GitHub repo docs — 80 diverse md (spread across repos, not 80 from one)
pick ~/Documents/GitHub \( -name "*.md" \) -size -1M | awk -F/ '{repo=$6; if (count[repo]++ < 3) print}' | head -80 | while IFS= read -r f; do
  repo=$(echo "$f" | awk -F/ '{print $6}' | tr ' ' '-' | tr -cd '[:alnum:]._-')
  copy "$f" "gh-$repo"
done

# 2. Data Science Discovery — 60 md/txt (calibration batch already took 20)
pick ~/Documents/"Data Science Discovery" \( -name "*.md" -o -name "*.txt" \) -size -1M | sed -n '21,80p' | while IFS= read -r f; do copy "$f" "dsd"; done

# 3. New project 2 — 40 md/txt
pick ~/Documents/"New project 2" \( -name "*.md" -o -name "*.txt" \) -size -1M | head -40 | while IFS= read -r f; do copy "$f" "np2"; done

# 4. Job Finder — 30 md/txt
pick ~/Documents/"Job Finder" \( -name "*.md" -o -name "*.txt" \) -size -1M | head -30 | while IFS= read -r f; do copy "$f" "job"; done

# 5. Loose Documents md/txt (top level)
find ~/Documents -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" \) -size -1M 2>/dev/null | while IFS= read -r f; do copy "$f" "doc"; done

# 6. PDFs — 12 small ones from Documents + Downloads
{ pick ~/Documents \( -name "*.pdf" \) -size -5M; pick ~/Downloads \( -name "*.pdf" \) -size -5M; } | head -12 | while IFS= read -r f; do copy "$f" "pdf"; done

# 7. DOCX — all (2)
pick ~/Documents \( -name "*.docx" \) -size -5M | head -4 | while IFS= read -r f; do copy "$f" "docx"; done

# 8. Images — 12 (Desktop screenshots + Documents, small)
{ pick ~/Desktop \( -name "*.png" \) -size -3M; pick ~/Documents \( -name "*.png" -o -name "*.jpg" \) -size -3M; } | head -12 | while IFS= read -r f; do copy "$f" "img"; done

# 9. CSV — 5 small (robustness: must index or fail into a defined state)
{ pick ~/Documents \( -name "*.csv" \) -size -200k; pick ~/Downloads \( -name "*.csv" \) -size -200k; } | head -5 | while IFS= read -r f; do copy "$f" "csv"; done

# 10. Audio — 2 small m4a (on-device transcription)
pick ~/Downloads \( -name "*.m4a" \) -size -2M | head -2 | while IFS= read -r f; do copy "$f" "aud"; done

echo "---"
echo "mount now has $(ls "$MOUNT" | grep -vc smfs-error) files"
