@description('Principal ID of the Function App managed identity')
param principalId string

@description('The Key Vault resource ID to scope the role assignment')
param keyVaultName string

@description('Role assignments to create')
param roleDefinitions roleDefinitionInfo[]

@export()
type roleDefinitionInfo = {
  @description('Built-in role definition ID (GUID)')
  roleDefinitionId: string

  @description('Description for the role assignment')
  description: string
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (role, index) in roleDefinitions: {
    name: guid(keyVault.id, principalId, role.roleDefinitionId)
    scope: keyVault
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.roleDefinitionId)
      description: role.description
    }
  }
]
