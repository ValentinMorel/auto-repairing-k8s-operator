#!/bin/sh

if kind get clusters | grep -q 'kind'; then
  echo "Kind cluster 'kind' already exists. Skipping creation."
else
  echo "Creating Kind cluster 'kind'..."
  kind create cluster --config=/kind-config.yaml
fi
