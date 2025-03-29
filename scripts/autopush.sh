#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
LOG_FILE=$NIX_DIR/log.txt

cd $NIX_DIR

git add .

log () {
  echo $(date +"%d-%m-%Y %H:%M") [AUTOPUSH] $1 >> "$LOG_FILE"
}

if [[ $(git log --max-count 1 | tail -n 1 | sed 's/^[ \t]*//') != "$(date +%d-%m-%Y)" ]]; then
  if [[ $(git status --porcelain) ]]; then

    git commit -m "$(date +%d-%m-%Y)"
    if git push; then
      log "Push successful."
    else
      log "Push failed."
    fi

  else
    log "No changes to commit."
  fi
else
  log "Already commited a change today."
fi

