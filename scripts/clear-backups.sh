#!/bin/sh

if [[ "$1" ]]; then
  BACKUP_DIR="$1"
else
  BACKUP_DIR="$XDG_CONFIG_HOME"
fi

BACKUPS=$(find $BACKUP_DIR -regex ".*\.backup$")

if [[ "$BACKUPS" ]]; then
  echo "--- $(echo "$BACKUPS" | wc -l) file(s) found ---"
  echo "$BACKUPS"
  echo ""
  echo "are you sure to delete them all? (y/n)"

  read x
  if [[ "$x" = "y" ]]; then
    echo "$BACKUPS" | while read backup; do
      rm "$backup"
    done
    echo "removed all."
  else
    echo "cancelled."
    exit 0
  fi
else
  echo "no backup files to remove."
  exit 0
fi

