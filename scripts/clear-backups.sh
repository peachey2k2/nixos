#!/bin/sh

BACKUPS=$(find $HOME -regex ".*\.backup$")

if [[ "$BACKUPS" ]]; then
  echo "--- $(echo "$BACKUPS" | wc -l) file(s) found ---"
  echo "$BACKUPS"
  echo ""
  echo "are you sure to delete them all? (y/n)"

  read x
  if [[ "$x" = "y" ]]; then
    rm $BACKUPS
    echo "removed all."
  else
    echo "cancelled."
    exit 1
  fi
else
  echo "no backup files to remove."
  exit 1
fi

