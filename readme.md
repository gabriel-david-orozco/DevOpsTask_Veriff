# Kubernetes cluster creation

In this case, I used Minikube for the sake of simplicity.

- Minikube version is: v1.24.0
- Kubernetes client version: v1.22.4
- Kubernetes server version: v1.22.3

Additionally, it's necessary to activate the ingress-nginx in minikube:

```
minikube addons enable ingress
```

# Deployment of the juice-shop service

```
      ┌─────────────────────────────────────────────────┐
      │                                                 │
      │  Kubernetes Cluster   ┌────────────────────┐    │
      │                       │  juice-shop-depl   │    │
      │                       │  ┌──────────────┐  │    │
      │                       │  │    pods      │  │    │
   ┌──┴───────┐            ┌──┴──┴───┐ ┌──────┐ │  │    │
   │          │            │juice-   │ │juice-│ │  │    │
   │ ingress- │       :3000│  shop   │ │  shop│ │  │    │
┌──┤►  nginx  ├────────────┤  service│ │docker│ │  │    │
│  │          │            │         │ │      │ │  │    │
│  └──┬───────┘            └──┬──┬───┘ └──────┘ │  │    │
│     │                       │  │              │  │    │
│     │                       │  └──────────────┘  │    │
│     │                       │                    │    │
│     │                       └────────────────────┘    │
│     │                                                 │
│     │                                                 │
│     └─────────────────────────────────────────────────┘
│                URL
│             ┌──────────────────────────────────┐
└─────────────┤http://juice-shop-creativity.link/│
              └──────────────────────────────────┘

```
- The creation of the namespace is in the file `juice-shop-namespace.yaml`. We handle the deployment, service exposure and ingress rules within the same namespace "juice-shop".
- The file `juice-shop-depl.yaml` specifies the parameters for the deployment. Only one replica of the pod running the container with the image bkimminich/juice-shop is necessary. No other parameters like resource limits are necessary since the deployment is very small.
- The file `juice-shop-svc.yaml` exposes as a service the port 3000 of the pods running juice-shop to the internal network of the cluster.
- `nginx-ingress.yaml` file creates the rules of ingress to use.

This part of the code specifies that the domain `juice-shop-creativity.link` should provide access to the juice-shop service. In the service block the name and the port points to that service. It is important to mention that domain shold be resolved to the cluster IP, for UNIX system adding the route in the /etc/hosts file is enough

```
spec:
  rules:
  - host: juice-shop-creativity.link
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

- `nginx.ingress.kubernetes.io/enable-modsecurity: "true"` activates the modsecurity.
- `nginx.ingress.kubernetes.io/enable-owasp-core-rules: "true"` activates the core rules for the modsecurity engine, including the detection of SQL injections. A full list of the security features can be found in "https://coreruleset.org/"
- On the other hand, the modsecurity default mode is Detection only, for that reason is necessary to set the `SecRuleEngine On` on `nginx.ingress.kubernetes.io/modsecurity-snippet` to activate the package filtering.

To see if the configuration is correctly applied we first need to retrieve the name of the pod running the ingress controller:

```
$ kubectl get pods -n ingress-nginx
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create--1-nchs9     0/1     Completed   0          6h24m
ingress-nginx-admission-patch--1-dtgqj      0/1     Completed   1          6h24m
ingress-nginx-controller-5f66978484-srg2w   1/1     Running     0          6h24m
```

With the pod name of the pod running the nginx-controller we see the parameters in the `/etc/nginx/nginx.conf` file and look for the `modsecurity` matches:

```
$ kubectl exec -n ingress-nginx ingress-nginx-controller-5f66978484-srg2w -- cat /etc/nginx/nginx.conf | grep "modsecurity"
load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;
			modsecurity on;
			modsecurity_rules '
			modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;
			modsecurity_rules_file /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf;
```
# Testing

For testing the sql injection we can use the login page of the juice-box in user and password we insert sql code and see the results, an example of sql code to insert could be:

```
‘ or ‘abc‘=‘abc‘;–
```

If the ingress rule and SQL injections protections are correctly activated. The result should be an 403 Forbidden. Otherwise the system will only return a 401 unautorized.

Aditionally, we can check for the logs of the pod running the nginx-ingress controller :
```
$ kubectl exec -n ingress-nginx ingress-nginx-controller-5f66978484-srg2w -- tail -1 /var/log/modsec_audit.log

juice-shop-creativity.link 192.168.64.1 - [01/Dec/2021:18:07:19 +0000] "POST /rest/user/login HTTP/1.1" 403 548 http://juice-shop-creativity.link/id=2 "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.55 Safari/537.36" 1638382039 http://juice-shop-creativity.link/id=2 /var/log/audit//20211201/20211201-1807/20211201-180719-1638382039 0 2950.000000 md5:5d716e109afc2eebca7ea7f102d4d762
```
This log will return the name of the file where the full log is stored. We can see it with the following command:

```
$ kubectl exec -n ingress-nginx ingress-nginx-controller-5f66978484-srg2w -- tail -f /var/log/audit//20211201/20211201-1807/20211201-180719-1638382039

ModSecurity: Warning. detected SQLi using libinjection. [file "/etc/nginx/owasp-modsecurity-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf"] [line "45"] [id "942100"] [rev ""] [msg ""] [data ""] [severity "0"] [ver "OWASP_CRS/3.3.2"] [maturity "0"] [accuracy "0"] [hostname "172.17.0.5"] [uri "/rest/user/login"] [unique_id "1638382039"] [ref "v11,30t:urlDecodeUni"]
ModSecurity: Warning. detected SQLi using libinjection. [file "/etc/nginx/owasp-modsecurity-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf"] [line "45"] [id "942100"] [rev ""] [msg ""] [data ""] [severity "0"] [ver "OWASP_CRS/3.3.2"] [maturity "0"] [accuracy "0"] [hostname "172.17.0.5"] [uri "/rest/user/login"] [unique_id "1638382039"] [ref "v11,30t:urlDecodeUniv14,30t:urlDecodeUni"]
ModSecurity: Access denied with code 403 (phase 2). Matched "Operator `Ge' with parameter `5' against variable `TX:ANOMALY_SCORE' (Value: `10' ) [file "/etc/nginx/owasp-modsecurity-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf"] [line "80"] [id "949110"] [rev ""] [msg "Inbound Anomaly Score Exceeded (Total Score: 10)"] [data ""] [severity "2"] [ver "OWASP_CRS/3.3.2"] [maturity "0"] [accuracy "0"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] [tag "attack-generic"] [hostname "172.17.0.5"] [uri "/rest/user/login"] [unique_id "1638382039"] [ref ""]
```

# Kubernetes cluster creation AWS 

Using the AWS console we create a Kubernetes cluster in EKS. In my case I created it in us-east-1.

```
eksctl create cluster --name juice-shop --version 1.21 --region us-east-1 --nodegroup-name standard-workers --node-type t3.micro --nodes 3 --nodes-min 1 --nodes-max 4 --managed
```
This process can take quite long for the creation of the Cloud Formation stack

For restricting the access to certain IP addresses in a CIDR group we use the command ` eks-update-cluster-config `

```
aws eks update-cluster-config \
    --region us-east-1 \
    --name Veriff-juice-shop \
    --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs="83.51.133.0/24",endpointPrivateAccess=true

```
The cluster should answer with the following:
```
{
    "update": {
        "id": "f4d2d45e-01ae-4d07-9bc9-a997ed87cf55",
        "status": "InProgress",
        "type": "EndpointAccessUpdate",
        "params": [
            {
                "type": "EndpointPublicAccess",
                "value": "true"
            },
            {
                "type": "EndpointPrivateAccess",
                "value": "true"
            },
            {
                "type": "PublicAccessCidrs",
                "value": "[\"83.51.133.0/24\"]"
            }
        ],
        "createdAt": "2021-12-02T10:36:06.277000+01:00",
        "errors": []
    }
}
```
For monitoring the status of the update we use the following:

```
aws eks describe-update --region us-east-1 --name Veriff-juice-shop --update-id f4d2d45e-01ae-4d07-9bc9-a997ed87cf55
```
Now, for the creation of the ingress-nginx controller, we need to add the addon and use a aws load balancer as ingress to the cluster.

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/aws/deploy.yaml
```

Finally, get the ingress DNS for the load balancer of the service:

```
PS C:\Users\gabri\Desktop\TSNControllers\DevOpsTask_Veriff> kubectl get ing -n juice-shop
NAME                 CLASS    HOSTS                        ADDRESS                                                                         PORTS   AGE
juice-shop-ingress   <none>   juice-shop-creativity.link   a9327a86cb45b48b59e1c1fd09b6487a-8066124fa7667380.elb.us-east-1.amazonaws.com   80      49m
```

In AWS we create can create a Route53 domain pointing to the loadbalancer DNS and it will be working

In our case, the public IP provided by the cluster is `54.160.27.207` so adding the hostname policy `54.160.27.207 juice-shop-creativity.link` in `/et/hosts` will be enough

Now, we can test the same SQL injections as in the Minikube deployment