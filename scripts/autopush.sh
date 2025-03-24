#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
AUTOPUSH_LOG=$NIX_DIR/autopush.log

cd $NIX_DIR

git add .

if [[ $(git log --max-count 1 | tail -n 1 | sed 's/^[ \t]*//')="$(date +%d-%m-%Y)" ]]; then
  if [[ $(git status --porcelain) ]]; then

    git commit -m "$(date +%d-%m-%Y)"
    if git push origin main; then
      echo "$(date): Push successful." >> "$AUTOPUSH_LOG"
    else
      echo "$(date): Push failed." >> "$AUTOPUSH_LOG"
    fi

  else
    echo "$(date): No changes to commit." >> "$LOG_FILE"
  fi
else
  echo "$(date): Already commited a change today." >> "$LOG_FILE"
fi

