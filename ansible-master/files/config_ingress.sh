kubectl patch svc ingress-nginx -n ingress-nginx --patch '{
  "spec": {
    "type": "LoadBalancer"
  }
}'
