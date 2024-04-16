# LiteLLM on GKE
This repo helps to deploy [LiteLLM](https://github.com/BerriAI/litellm) on GKE with one step. 

**why need proxy?**
1. Existing OpenAI users do not need to change the code. They only need to modify the URL and API Key to access Gemini.
2. Build a Proxy to solve the problem of inability to access Google API in China
3. Build a unified Gemini Proxy platform. Various applications can be directly connected using API Key. There is no need to integrate GCP SA.
4. If existing open source projects already support OpenAI. With this, they will be compatible with all without the need for major modifications.

## Prepare your LiteLLM config yaml file
```
git clone https://github.com/zhmichael007/litellm-gke
cd litellm-gke
```
Edit config.yaml
1. modify "vertex_project" and "vertex_location"
2. modify "master_key"
3. modify the model list
<img width="381" alt="image" src="https://github.com/zhmichael007/litellm-gke/assets/19321027/828657c5-36ab-4344-8a15-a3e7ced60da5">



## Create LiteLLM Proxy Cluster in GKE
modify these parameters in deploy.sh:
```
PROJECT_ID=
CLUSTER_NAME=litellm-proxy
REGION=us-central1
MASTER_ZONE=us-central1-a
ZONE=(us-central1-a us-central1-b us-central1-c)
NETWORK=default
MAX_NODES=3
MACHINE_TYPE=e2-custom-2-1024
DISK_SIZE="50" 
KSA_NAME=k8s-sa 
APP_SA_NAME=litellm-sa
```
```
bash deploy.sh
```

## Deploy the Deployment and Service of LiteLLM Proxy Cluster
If you need IP whitelist, modify the loadBalancerSourceRanges in service.yaml, this will provide a IP white list in firewall for security
<img width="471" alt="image" src="https://github.com/zhmichael007/litellm-gke/assets/19321027/29a0bafb-3765-4c92-943c-5a8323a5c316">

```
kubectl create configmap litellm-config-file --from-file=./config.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Test
- use curl to test
```
kubectl get svc litellm-service
```
```
curl --location 'http://<YOUR_SERVICE_IP>:80/completions' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <YOUR MASTER KEY>' \
--data ' {
      "model": "gemini-1.0-pro-002",
      "prompt": "Hello World!"
    }
'
```
sample result:
```
{"id":"chatcmpl-34486f4e-cb0d-4502-8fb1-6562e59de8d0","object":"text_completion","created":1713180465,"model":"gemini-1.0-pro-002","choices":[{"finish_reason":"stop","index":0,"text":"Hello World! 👋 \n\nIt's nice to meet you. What would you like to talk about today?","logprobs":null}],"usage":{"prompt_tokens":3,"completion_tokens":23,"total_tokens":26}}
```

## Update your config.yaml file
1. Upload your new config.yaml to a new configmap
```
kubectl delete configmap litellm-config-file
kubectl create configmap litellm-config-file --from-file=./config.yaml
```
2. Reload the GKE
```
kubectl delete -f deployment.yaml
kubectl apply -f deployment.yaml
```
