#!/bin/sh

BACKUPS=$(find $XDG_CONFIG_HOME -regex ".*\.backup$")

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
    exit 1
  fi
else
  echo "no backup files to remove."
  exit 1
fi

