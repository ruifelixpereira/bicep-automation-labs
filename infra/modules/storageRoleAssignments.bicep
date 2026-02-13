@description('Principal ID of the Function App managed identity')
param principalId string

@description('Name of the Storage Account to scope the role assignments')
param storageAccountName string

@description('Role assignments to create')
param roleDefinitions roleDefinitionInfo[]

@export()
type roleDefinitionInfo = {
  @description('Built-in role definition ID (GUID)')
  roleDefinitionId: string

  @description('Description for the role assignment')
  description: string
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (role, index) in roleDefinitions: {
    name: guid(storageAccount.id, principalId, role.roleDefinitionId)
    scope: storageAccount
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.roleDefinitionId)
      description: role.description
    }
  }
]
