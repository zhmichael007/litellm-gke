# LiteLLM on CloudRun
This repo helps to deploy [LiteLLM](https://github.com/BerriAI/litellm) on GKE with one step. 

**why need proxy?**
1. Existing OpenAI users do not need to change the code. They only need to modify the URL and API Key to access Gemini.
2. Build a Proxy to solve the problem of inability to access Google API in China
3. Build a unified Gemini Proxy platform. Various applications can be directly connected using API Key. There is no need to integrate GCP SA.
4. If existing open source projects already support OpenAI. With this, they will be compatible with all without the need for major modifications.

## Prepare your LiteLLM config yaml file
Edit config.yaml
1. modify "vertex_project" and "vertex_location"
2. modify "master_key"
3. modify the model list

## Create LiteLLM Proxy Cluster in GKE
```
modify these parameters in deploy.sh:
PROJECT_ID=
CLUSTER_NAME=litellm-proxy
REGION=us-central1
MASTER_ZONE=us-central1-a
ZONE=(us-central1-a us-central1-b us-central1-c)
NETWORK=default
MAX_NODES=3
MACHINE_TYPE=e2-custom-2-1024
DISK_SIZE="50" 
KSA_ROLE=roles/aiplatform.user
KSA_NAME=k8s-sa 
APP_SA_NAME=litellm-sa
```
```
bash deploy.sh
```

## Deploy the Deployment and Service of LiteLLM Proxy Cluster
```
kubectl create configmap litellm-config-file --from-file=path/config.yaml
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
{"id":"chatcmpl-abf4eb0b-b275-47f8-8e36-b0649c43c346","choices":[{"finish_reason":"stop","index":0,"message":{"content":"I am Gemini, a multi-modal AI model, developed by Google.","role":"assistant"}}],"created":1713067892,"model":"gemini-1.0-pro-001","object":"chat.completion","system_fingerprint":null,"usage":{"prompt_tokens":5,"completion_tokens":15,"total_tokens":20}}
```

## Update your config.yaml file
1. Upload your new config.yaml to a new secret version
```
kubectl delete configmap litellm-config-file
kubectl create configmap litellm-config-file --from-file=path/config.yaml
```
2. Reload the GKE
```
kubectl delete -f service.yaml
kubectl apply -f service.yaml
```

## Clean
```
export PROJECT_ID=your_project_id
export REGION=region_name
bash clean.sh
```
