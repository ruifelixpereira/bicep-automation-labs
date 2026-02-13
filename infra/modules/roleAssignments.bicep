@description('Principal ID of the managed identity to assign roles to')
param principalId string

@description('Resource ID of the target resource to scope the role assignments')
param scopeResourceId string

@description('Role assignments to create')
param roleDefinitions roleDefinitionInfo[]

@export()
type roleDefinitionInfo = {
  @description('Built-in role definition ID (GUID)')
  roleDefinitionId: string

  @description('Description for the role assignment')
  description: string
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (role, index) in roleDefinitions: {
    name: guid(scopeResourceId, principalId, role.roleDefinitionId)
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.roleDefinitionId)
      description: role.description
    }
  }
]
