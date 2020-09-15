{
    "Service": { 
        "Name": "pub-api",
        "Tags": ["application","production"],
        "Port": 8080,
        "Checks": [
            {
                "id": "pub-api-tcp-8080",
                "name": "TCP Port Listening - 8080",
                "tcp": "localhost:8080",
                "interval": "10s",
                "timeout": "1s"
            },
            {
                "id": "pub-api-http-8080",
                "name": "HTTP Server - 8080",
                "http": "http://localhost:8080",
                "tls_skip_verify": true,
                "interval": "10s",
                "timeout": "2s"
            }
        ]
    }
}