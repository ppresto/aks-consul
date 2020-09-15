# Provision AKS and Install Vault with Integrated Storage
Using Terraform we will provision a 3 node AKS cluster and deploy a 3 server consul cluster using helm.  Post Installation, we will configuring Kubernetes CoreDNS to forward requests to consul and deploy a simple dashboard and counting api service that will rely on service names.
Note: 
* sensitive k8s data will be stored in `tmp/k8s_config`

## Provisioning
Update `consul.auto.tfvars` with your environment information like resource group, and k8s cluster name.

## Prereq
Export azure environment variables
```
ARM_SUBSCRIPTION_ID
ARM_CLIENT_SECRET
ARM_TENANT_ID
ARM_CLIENT_ID
```

## Setup - No Server Encryption (Gossip, TLS, ACL)
First this guide will setup consul without encryption to easily troubleshoot apps in development.  Second we will lock it all down for a more secure implementation.

### Provision Consul in an Existing AKS Cluster
```
helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul

kubectl create namespace consul
helm install sec hashicorp/consul -f helm-consul-insecure.yaml  -n consul

kubectl get service sec-consul-ui -n consul --watch
```
Open a new browser tab to http://<EXTERNAL-IP>.  

You can also use the consul CLI locally by setting your environment
```
export CONSUL_HTTP_ADDR="http://$(kubectl get svc sec-consul-ui -n consul\
  -o jsonpath={.status.loadBalancer.ingress[].ip} \
  )"
consul members
```

### Setup Consul DNS
Get Consul's DNS Service clusterIP.  We will forward CoreDNS requests to this service endpoint for consul's custom domain (service.consul).
```
export CONSUL_DNS_IP=$(kubectl get svc sec-consul-dns -n consul -o jsonpath='{.spec.clusterIP}')
echo $CONSUL_DNS_IP
```

As of Kubernetes 1.12 kube-dns is replaced with CoreDNS.  The svc is still named kube-dns for compatability.  To forward `*.service.consul` requests to consul update this configmap with the stub domain and $CONSUL_DNS_IP.
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: coredns-custom
  namespace: kube-system
data: 
  consul.server: |
    service.consul:53 {
      errors
      cache 30
      forward . $CONSUL_DNS_IP
    }
  log.override: | # you may select any name here, but it must end with the .override file extension
    log
EOF

kubectl get configmap coredns-custom -n kube-system -o yaml
```
Note: the configmap keys must be *.server and *.override for kubernetes to pick up custom configurations.  We should see our changes and $CONSUL_DNS_IP in the configmap.  

Delete the CoreDNS pod to reload the DNS service.
```
kubectl delete pod --namespace kube-system -l k8s-app=kube-dns
```

#### Test Consul DNS
```
kubectl apply -f k8s/tests/dns.yaml
dnspod=$(kubectl get pods | grep dns | awk '{ print $1 }')
kubectl logs $dnspod dns
kubectl delete -f k8s/tests/dns.yaml
```
If DNS is configured properly you should see ANSWERS > 0.

### Discovery - Deploy Counter/Dashboard App
The Dashboard app will show a number that was fetched from the backend counting API. It will increment every few seconds.  These apps use an init container that takes the node and pod IP as arguments in order to register them into consul. 
```
kubectl apply -f k8s/02-yaml-discovery
kubectl get service dashboard-service-load-balancer --watch
```

### Service Mesh - Deploy Counter/Dashboard App
This repo has various configurations of service mesh deployments. 
* `./03-yaml-connect` uses consul 1.3 agent as a sidecar proxy and an init container to register its services
* `./04-yaml-connect-envoy` uses envoy with the default ns and sa.
* `./05-yaml-connect-envoy-sa-ns` uses envoy and each service (dashboard, counting) has its own namespaces, and sa.
```
kubectl apply -f k8s/05-yaml-connect-envoy-sa-ns
kubectl get svc -n dashboard -w
```
Open a new browser tab to http://<EXTERNAL-IP>

#### Consul Gossip: Verify its unsecure
```
kubectl exec -it consul-server-0 -- /bin/sh
apk update && apk add tcpdump
tcpdump -an portrange 8300-8700 -A | grep "Protocol"
#tcpdump -an portrange 8300-8700 -A > /tmp/tcpdump.log
```
UDP operations are not encrypted.  These are the gossip protocol at work.

#### Consul RPC: Verify its unsecure
```
kubectl exec -it consul-server-0 -- /bin/sh
apk update && apk add tcpdump
tcpdump -an portrange 8300-8700 -A | grep "ServiceMethod"
# ServiceMethod.Catalog.ListServices
# ServiceMethod.Catalog.Register
```

Generate traffic to the server from one of the consul clients.
```
kubectl exec $(kubectl get pods -l component=client -o jsonpath='{.items[0].metadata.name}') -- consul catalog services
```


## Setup - Secure Server

Use the helm chart to enable security parameters.  Pass the gossip encryption key to helm using a K8s secret.  Generate this key using consul keygen.  If it doesn't exist, first run `kubectl create namespace consul`

```
kubectl create secret generic consul-gossip-encryption-key --from-literal=key=$(consul keygen) -n consul

helm install sec hashicorp/consul -f helm-consul-secure.yaml -n consul
```
Consul should now be secure.  Lets check.

### Validate TLS Verification is being enforced
Setup a port forward in a different terminal window
```
kubectl port-forward --address 0.0.0.0 sec-consul-server-0 8501:8501
```

Setup env, ca.pem, and validate by listing consul members
```
export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
kubectl get secret sec-consul-ca-cert -o jsonpath="{.data['tls\.crt']}" -n consul | base64 --decode > tmp/ca.pem

consul members  # this should Fail with no CA.
consul members -ca-file tmp/ca.pem
export CONSUL_CACERT="tmp/ca.pem"
consul members

```
Seeing the consul memebers after applying the CA prove TLS is being enforced

### Validate ACLs are being enforced

Launch a debug session.  You should get 403 (Permission denied) because we haven't supplied an ACL token.  Consul helm created an anonymous token with a read policy for node/service enabling `consul members` to work.
```
consul debug -ca-file ca.pem
```

This secret contains the Consul ACL bootstrap token. The bootstrap token is a full access token that can perform any operation in the service mesh.  Set this in your environment.
```
export CONSUL_HTTP_TOKEN=$(kubectl get secrets/sec-consul-bootstrap-acl-token --template={{.data.token}} -n consul | base64 --decode)
```
Now try to start a debug session `consul debug -ca-file tmp/ca.pem`.  This proves ACL's are being enforced. 

### Validate Gossip and RPC are encrypted
Install tcpdump and log network traffic so we can verify its encrypted.
```
kubectl exec -it sec-consul-server-0 -- /bin/sh
apk update && apk add tcpdump
tcpdump -an portrange 8300-8700 -A > /tmp/tcpdump.log
```

In another terminal try to list services using the consul CLI.  You should see `consul` as the output.
```
kubectl exec $(kubectl get pods -l component=client -o jsonpath='{.items[0].metadata.name}') -- consul catalog services -token $(kubectl get secrets/sec-consul-bootstrap-acl-token --template={{.data.token}} | base64 --decode)
```

Go back to the tcpdump. stop the dump ^c and review the log for any visible RPC request.
```
grep 'ServiceMethod' /tmp/tcpdump.log
```
If nothing was returned then you didn't find any RPC requests in clear text.  THis proves RPC traffic is encrypted.

### Get Secrets
```
kubectl get secrets consul-gossip-encryption-key -o jsonpath="{.data.key}"
export CONSUL_HTTP_TOKEN=$(kubectl get secret/sec-consul-bootstrap-acl-token -o jsonpath="{.data.token}")

#server config
kubectl get configmap/sec-consul-server-config -o jsonpath="{.data}"

```
## Observability

```
helm repo add stable https://kubernetes-charts.storage.googleapis.com
```

### Install Prometheus
```
helm install -f k8s/prometheus/prometheus-values.yaml prometheus stable/prometheus

# Alert Manager
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus,component=alertmanager" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9093

# Push Gateway
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9091
```
Note:  For hardened instance with K8s dashboards install the operator version: `helm install prometheus stable/prometheus-operator`

### Install Grafana
```
helm install -f k8s/grafana/grafana-values.yaml grafana stable/grafana

# Get Password for 'admin'
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Grafana URL
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")

kubectl --namespace default port-forward $POD_NAME 3000
```
Log into the grafana dashboard at localhost:3000 with user: admin.  Manage Dashboards and import a working template at `./k8s/grafana/overview_dashboard.json`.  There is no traffic yet...

Install Emoji application and setup traffic simulator to see metrics.
```
kubectl apply -f k8s/emoji
echo "http://$(kubectl get svc emojify-ingress -o jsonpath={.spec.clusterIP}):30000"
```


## Next Steps...
[Setup a Vault Namespace Project](../vault-project-template "Setup a Vault Namespace Project")