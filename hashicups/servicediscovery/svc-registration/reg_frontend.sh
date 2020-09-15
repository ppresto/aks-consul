{
    "Service": { 
        "Name": "frontend",
        "Tags": ["application","production"],
        "Port": 80,
        "Checks": [
            {
                "id": "frontend-tcp-80",
                "name": "TCP Port Listening - 80",
                "tcp": "localhost:80",
                "interval": "10s",
                "timeout": "2s"
            },
            {
                "id": "frontend-http-80",
                "name": "Nginx Gateway - 80",
                "http": "http://localhost:80/api",
                "tls_skip_verify": true,
                "method": "POST",
                "header": {"Content-Type": ["application/json"]},
                "body": "{\"query\":\"{coffees{id name image price teaser description}}\"}",
                "interval": "5s",
                "timeout": "2s"
            }
        ]
    }
}
