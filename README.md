# foundry-agents-mcp-scenarios

Sample agents built on the Azure AI Foundry CB Agent framework.

## Repository structure

```
examples/
  foundry-cbagent-hello/               # Minimal "Hello, World!" agent
    main.py                            # Agent implementation (HelloWorldAgent)
    requirements.txt                   # Python dependencies
    Dockerfile                         # Container image for deployment
    azure.yaml                         # azd deployment manifest
    infra/                             # Bicep infrastructure-as-code
      main.bicep                       #   Orchestrator (RG + modules)
      main.parameters.json             #   Maps azd env vars → Bicep params
      modules/
        hub-dependencies.bicep         #   Storage Account + Key Vault
        hub.bicep                      #   AI Foundry Hub + AI Services connection
        project.bicep                  #   AI Foundry Project
        container-registry.bicep       #   Azure Container Registry
        container-app.bicep            #   Container App Environment + Container App
```

## Prerequisites

- Python 3.10+
- [Azure CLI (`az`)](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- An existing **AI Services** resource (kind `AIServices`) in your Azure subscription

## Quick start — run locally

```bash
cd examples/foundry-cbagent-hello
python -m venv .venv
source .venv/bin/activate   # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

The agent server starts on port **8088**.
Test it with:

```bash
curl -X POST http://localhost:8088/runs \
  -H "Content-Type: application/json" \
  -d '{"input": "hello"}'
```

Expected response:

```json
{
  "id": "hello-world",
  "output": [
    {
      "status": "completed",
      "content": [{ "text": "Hello, World!", "type": "output_text" }],
      "type": "message",
      "role": "assistant"
    }
  ],
  "object": "response"
}
```

## Deploy to Azure

### Architecture

`azd provision` creates a **new resource group** with the following resources.
Your existing AI Services resource remains in its original resource group and is
referenced via a Hub connection:

```
rg-<env-name>  (new, managed by azd)
├── Storage Account              ← required by Hub
├── Key Vault                    ← required by Hub
├── AI Foundry Hub               ← connects to your existing AI Services
│   └── AI Services Connection   (AAD auth, cross-RG reference)
├── AI Foundry Project           ← child of Hub
├── Container Registry (ACR)     ← stores agent Docker images
├── User-Assigned Managed Identity ← AcrPull on the registry
├── Container App Environment    ← hosting environment
└── Container App                ← runs the agent container (port 8088)
```

### Deployment steps

There are **three steps**: provision infrastructure, build the image, then
update the Container App. The whole flow takes ~5 minutes.

#### 1. Log in & configure environment

```bash
cd examples/foundry-cbagent-hello

azd auth login
azd init -e <env-name>            # e.g. cbagent-hello-dev

azd env set AZURE_SUBSCRIPTION_ID "<subscription-id>"
azd env set AZURE_LOCATION        "westus2"

# Resource ID of your existing AI Services account
azd env set AI_SERVICES_RESOURCE_ID \
  "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<name>"

# Endpoint of the same AI Services account
azd env set AI_SERVICES_ENDPOINT "https://<name>.cognitiveservices.azure.com/"
```

#### 2. Provision infrastructure (~3-4 min)

```bash
azd provision
```

This creates the resource group, Hub, Project, ACR, Container App
Environment, managed identity, role assignments, and Container App in a
single ARM deployment.

#### 3. Build & push the agent image (~30 sec)

Build the Docker image in the cloud using ACR Build (no local Docker needed):

```bash
az acr build \
  --registry <acr-name> \
  --image agent:latest \
  ./examples/foundry-cbagent-hello
```

> The ACR name is printed as an `azd provision` output
> (`AZURE_CONTAINER_REGISTRY_NAME`).  You can also retrieve it with
> `azd env get-value AZURE_CONTAINER_REGISTRY_NAME`.

After the image is pushed, update the Container App:

```bash
azd deploy
```

#### Verify

```bash
FQDN=$(azd env get-value AGENT_FQDN)

# Health check
curl https://$FQDN/liveness        # → HTTP 200

# Run the agent
curl -X POST https://$FQDN/runs \
  -H "Content-Type: application/json" \
  -d '{"input": "hello"}'
```

### Update the agent

After code changes, rebuild and redeploy:

```bash
az acr build --registry <acr-name> --image agent:latest ./examples/foundry-cbagent-hello
azd deploy
```

### Tear down

To delete all provisioned resources:

```bash
azd down
```

This removes the `rg-<env-name>` resource group and everything inside it.
Your original AI Services resource is **not** affected.