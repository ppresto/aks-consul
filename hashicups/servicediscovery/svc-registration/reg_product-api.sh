{
    "Service": { 
        "Name": "product-api",
        "Tags": ["application","production"],
        "Port": 9090,
        "Checks": [
            {
                "id": "product-api",
                "name": "Product API - TCP 9090",
                "tcp": "localhost:9090",
                "interval": "10s",
                "timeout": "1s"
            },
            {
                "id": "product-api-http-9090",
                "name": "Product API - HTTP 9090",
                "http": "http://localhost:9090/coffees",
                "tls_skip_verify": true,
                "interval": "5s",
                "timeout": "2s"
            }
        ]
    }
}