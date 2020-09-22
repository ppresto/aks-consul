#!/bin/sh

cat <<EOF > service.json
{
  "Name": "frontend",
  "Tags": ["application","production"],
  "Address": "${POD_IP}",
  "Port": 80,
  "Check": {
    "Method": "GET",
    "HTTP": "http://${POD_IP}:80",
    "Interval": "1s"
  }
}
EOF

curl \
    --request PUT \
    --data @service.json \
    "http://$HOST_IP:8500/v1/agent/service/register"
