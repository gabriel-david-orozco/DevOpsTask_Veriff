# Kubernetes cluster creation

In this case, I used Minikube for the sake of simplicity.

Minikube version is: v1.24.0
Kubernetes client version: v1.22.4
Kubernetes server version: v1.22.3

Additionally, running 
# Deployment of the juice-shop service

- The creation of the namespace is in the file `juice-shop-namespace.yaml`. We handle the deployment, service exposure and ingress rules within the same namespace "juice-shop".
- The file `juice-shop-depl.yaml` specifies the parameters for the deployment. Only one replica of the pod running the container with the image bkimminich/juice-shop is necessary. No other parameters like resource limits are necessary since the deployment is very small.
- The file `juice-shop-svc.yaml` exposes as a service the port 3000 of the pods running juice-shop to the internal network of the cluster.
- `nginx-ingress.yaml` file creates the rules of ingress to use.

This part of the code specifies that the domain juiceshop-creativity.com should provide access to the juice-shop service. In the service block the name and the port points to that service.

```
spec:
  rules:
  - host: juiceshop-creativity.com
    http:
      paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: juice-shop
                  port:
                    number: 3000
```
On the other hand, in the metadata of the Ingress we create the rules of the configmap of the modsecurity WAF engine running on the ingress-nginx.

```
metadata:
  annotations:
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/enable-owasp-core-rules: "true"
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
  name: juice-shop-ingress
  namespace: juice-shop
```
`nginx.ingress.kubernetes.io/enable-modsecurity: "true"` activates the modsecurity.
`nginx.ingress.kubernetes.io/enable-owasp-core-rules: "true"` activates the core rules for the modsecurity engine, including the detection of SQL injections. A full list of the security features can be found in "https://coreruleset.org/"



