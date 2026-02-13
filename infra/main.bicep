targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name used to derive resource names')
param baseName string

@description('The tenant ID for Key Vault RBAC')
param tenantId string = subscription().tenantId

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Deploy a sample secret into the Key Vault')
param deploySampleSecret bool = false

// ---------- Derived names ----------
var keyVaultName = 'kv-${baseName}-${environment}'
var functionAppName = 'func-${baseName}-${environment}'
var appServicePlanName = 'asp-${baseName}-${environment}'
var storageAccountName = replace('st${baseName}${environment}', '-', '')

// ---------- Key Vault Role Definition IDs ----------
// Key Vault Secrets User   : 4633458b-17de-408a-b874-0445c86b69e6
// Key Vault Crypto User    : 12338af0-0e69-4776-bea7-57ae8d297424
// Key Vault Reader          : 21090545-7ca7-4776-b22c-e363652d74d2
var keyVaultRoleDefinitions = [
  {
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
    description: 'Allow Function App to read secrets from Key Vault'
  }
  {
    roleDefinitionId: '12338af0-0e69-4776-bea7-57ae8d297424'
    description: 'Allow Function App to use cryptographic keys in Key Vault'
  }
  {
    roleDefinitionId: '21090545-7ca7-4776-b22c-e363652d74d2'
    description: 'Allow Function App to read Key Vault metadata'
  }
]

// ---------- Storage Account Role Definition IDs ----------
// Storage Blob Data Owner            : b7e6dc6d-f1e8-4753-8033-0f276bb0955b
// Storage Account Contributor        : 17d1049b-9a84-46fb-8f53-869881c3d3ab
// Storage Queue Data Contributor     : 974c5e8b-45b9-4653-ba55-5f855dd0fb88
// Storage File Data Privileged Cont. : 69566ab7-960f-475b-8e7c-b3118f30c6bd
var storageRoleDefinitions = [
  {
    roleDefinitionId: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    description: 'Allow Function App to read/write blob data in Storage Account'
  }
  {
    roleDefinitionId: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
    description: 'Allow Function App to process queue messages in Storage Account'
  }
  {
    roleDefinitionId: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
    description: 'Allow Function App to access file shares in Storage Account'
  }
  {
    roleDefinitionId: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
    description: 'Allow Function App to manage Storage Account (content share provisioning)'
  }
]

// ---------- Deploy Key Vault first ----------
module keyVault 'modules/keyVault.bicep' = {
  params: {
    location: location
    keyVaultName: keyVaultName
    tenantId: tenantId
    deploySampleSecret: deploySampleSecret
  }
}

// ---------- Deploy Function App (depends on Key Vault for URI) ----------
module functionApp 'modules/functionApp.bicep' = {
  params: {
    location: location
    functionAppName: functionAppName
    appServicePlanName: appServicePlanName
    storageAccountName: storageAccountName
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

// ---------- Create role assignments on Key Vault for Function App identity ----------
module keyVaultRoleAssignments 'modules/roleAssignments.bicep' = {
  params: {
    principalId: functionApp.outputs.functionAppPrincipalId
    keyVaultName: keyVault.outputs.keyVaultName
    roleDefinitions: keyVaultRoleDefinitions
  }
}

// ---------- Create role assignments on Storage Account for Function App identity ----------
module storageRoleAssignments 'modules/storageRoleAssignments.bicep' = {
  params: {
    principalId: functionApp.outputs.functionAppPrincipalId
    storageAccountName: functionApp.outputs.storageAccountName
    roleDefinitions: storageRoleDefinitions
  }
}

// ---------- Outputs ----------
output functionAppName string = functionApp.outputs.functionAppName
output functionAppHostName string = functionApp.outputs.functionAppDefaultHostName
output keyVaultName string = keyVault.outputs.keyVaultName
output keyVaultUri string = keyVault.outputs.keyVaultUri
