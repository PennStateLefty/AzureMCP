# MCP Flex Consumption Azure Function Infrastructure (Bicep)

This folder contains Bicep IaC to provision a .NET 9 isolated Azure Function on the Flex Consumption (FC1) plan with:
- System-assigned managed identity
- Identity-based (preview / evolving) storage access configuration (no key in app settings)
- Workspace-based Application Insights (Log Analytics)
- Role assignments for Blob + Queue Data Contributor on the storage account
- Simplified first pass: storage public network access allowed (harden later with private endpoints / firewall)

> NOTE: Identity-based primary `AzureWebJobsStorage` usage is still maturing. If runtime features (e.g., timers, queues, durable) fail to initialize, you may temporarily need the traditional connection string using a storage key until GA.

## Files
- `main.bicep` – All resources (plan, storage, function app, insights, roles)

## Parameters
| Name | Description | Default |
|------|-------------|---------|
| prefix | Resource prefix (naming) | `mcp` |
| location | Azure region | RG location |
| functionAppName | Function App name | `<prefix>-func` |
| storageAccountName | (Optional) Override storage name (3-24). Empty = auto-generate | auto |
| logAnalyticsWorkspaceName | LA workspace name | `<prefix>-law` |
| appInsightsName | App Insights name | `<prefix>-appi` |
| tags | Object of tags | basic dev tags |

## Deploy (What-If + Create)
```bash
# What-if (preview changes)
az deployment group what-if \
  --resource-group rg-mcp-demo \
  --template-file infra/mcp/main.bicep \
  --parameters prefix=mcpdemo

# Deploy
az deployment group create \
  --resource-group rg-mcp-demo \
  --template-file infra/mcp/main.bicep \
  --parameters prefix=mcpdemo
```
If you need custom names:
```bash
az deployment group create \
  -g rg-mcp-demo \
  -f infra/mcp/main.bicep \
  -p prefix=mcpdemo functionAppName=mcpdemo-func storageAccountName=mcpdemostabc123
```
> Storage account names must be globally unique (3–24 lowercase alphanumerics).

## Outputs
- `functionAppName`
- `functionAppHostname`
- `functionAppPrincipalId`
- `storageName`
- `appInsightsConnectionString`

## Post-Deployment: Publish Function Code
From the solution root (ensure you compiled the .NET isolated function targeting .NET 9):
```bash
# Build (adjust project path if needed)
dotnet build src/AzureFunctionMCP/AzureFunctionMCP.csproj -c Release

# Zip deploy using Azure Functions Core Tools (if installed)
func azure functionapp publish $(az deployment group show -g rg-mcp-demo -n <deploymentName> --query properties.outputs.functionAppName.value -o tsv)

# OR using az CLI + ZIP (example)
funcAppName=<your-func-app-name>
zip -r functionapp.zip ./src/AzureFunctionMCP/bin/Release/net9.0/publish
az functionapp deployment source config-zip -g rg-mcp-demo -n $funcAppName --src functionapp.zip
```

## Hardening Roadmap (Later)
1. Set `networkAcls.defaultAction` to `Deny` and add private endpoints (blob/queue) + VNet integration.
2. Disable `allowSharedKeyAccess` when Microsoft officially supports full identity-only host storage.
3. Add Key Vault and move any future secrets there.
4. Add diagnostic settings routing to Log Analytics / Storage / Event Hub.
5. Set IP restrictions on Function App (access restrictions).

## Troubleshooting
| Issue | Possible Cause | Action |
|-------|----------------|--------|
| Function startup errors referencing storage | Identity-based host storage not fully supported for your triggers | Add traditional `AzureWebJobsStorage` app setting with key temporarily |
| Role assignment not effective immediately | RBAC propagation delay | Wait a few minutes or re-run function after warm restart |
| Logs not appearing in App Insights | Connection string missing or ingestion delay | Confirm app settings + check `appi` resource in portal |

## Clean Up
```bash
az group delete -n rg-mcp-demo --yes --no-wait
```

## Next Steps
- Integrate CI/CD (GitHub Actions or Azure DevOps) calling `az deployment group what-if` then `create`.
- Add unit + integration tests for the function.
- Introduce environment-based prefixes (e.g., `mcprd`, `mcpstg`).

---
Generated following Azure and Functions best practices (simplified first iteration). Harden networking and secret posture in subsequent revisions.
