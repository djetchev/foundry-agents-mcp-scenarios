# foundry-agents-mcp-scenarios

Sample agents built on the Azure AI Foundry CB Agent framework.

## Repository structure

```
examples/
  foundry-cbagent-hello/ # Minimal "Hello, World!" agent
    main.py              # Agent implementation (HelloWorldAgent)
    requirements.txt     # Python dependencies
    azure.yaml           # azd deployment manifest
    infra/               # Bicep infrastructure-as-code
```

## Quick start

```bash
cd examples/foundry-cbagent-hello
python -m venv .venv
source .venv/bin/activate   # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
python main.py
```