kubectl patch daemonsets kube-flannel-ds-amd64 -n kube-system --patch='{
  "spec":{
    "template":{
      "spec":{
        "containers":[
        {
          "name": "kube-flannel",
          "args":[
          "--ip-masq",
          "--kube-subnet-mgr",
          "--iface=eth1"
          ]
        }
        ]
      }
    }
  }
}'
