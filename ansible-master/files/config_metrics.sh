kubectl patch deployment/metrics-server -n kube-system --patch '{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "metrics-server",
            "command":[
              "/metrics-server",
              "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
              "--kubelet-insecure-tls"
            ]
          }
        ]
      }
    }
  }
}'
