#!/bin/sh
cat <<EOF > svc_postgres.json
{
    "Service": { 
        "Name": "postgres",
        "Tags": ["application","production"],
        "Port": 80,
        "Check": {
            "id": "postgres",
            "name": "DB traffic on port 5432",
            "tcp": "localhost:5432",
            "interval": "10s",
            "timeout": "2s"
        }
    }
}
EOF

curl \
    --request PUT \
    --data @svc_postgres.json \
    "http://$HOST_IP:8500/v1/agent/service/register"
