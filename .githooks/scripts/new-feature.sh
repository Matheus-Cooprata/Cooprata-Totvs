#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./new-feature.sh <nome-da-feature>"
  exit 1
fi
git checkout hml && git pull origin hml
git checkout -b "feature/$1"
echo "✅ Branch feature/$1 criada a partir da hml."
