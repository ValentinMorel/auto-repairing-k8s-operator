#!/bin/bash

cd ../deployments
kubectl apply -f deployments.yaml
kubectl apply -f operator.yaml
kubectl apply -f prometheus.yaml
kubectl apply -f alertmanager.yaml
