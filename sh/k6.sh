#!/bin/sh

if [ $# -ne 1 ]; then
  echo "Usage: $0 <vus_value>"
  exit 1
fi

echo "Executing k6 with ${VUS} vus"
VUS=$1 k6 run ./k6/script.js
