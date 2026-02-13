@description('Azure region for the Key Vault')
param location string

@description('Name of the Key Vault')
param keyVaultName string

@description('The tenant ID for the Key Vault')
param tenantId string

@description('Deploy a sample secret into the Key Vault')
param deploySampleSecret bool = false

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// ---------- Sample secret ----------
resource sampleSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (deploySampleSecret) {
  parent: keyVault
  name: 'sample-secret'
  properties: {
    value: 'Hello from Key Vault!'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
