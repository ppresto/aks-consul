#!/bin/sh

curl \
    --request PUT \
    --data @service.json \
    "http://$HOST_IP:8500/v1/agent/service/register"
