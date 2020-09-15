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