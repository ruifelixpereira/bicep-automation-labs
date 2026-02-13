targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name used to derive resource names')
param baseName string

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

// ---------- Derived names ----------
var logAnalyticsName = 'log-${baseName}-${environment}'
var appInsightsName = 'appi-${baseName}-${environment}'

// ---------- Deploy Application Insights + Log Analytics ----------
module appInsights '../../modules/appInsights.bicep' = {
  params: {
    location: location
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    retentionInDays: retentionInDays
  }
}

// ---------- Outputs ----------
output appInsightsName string = appInsights.outputs.appInsightsName
output appInsightsInstrumentationKey string = appInsights.outputs.appInsightsInstrumentationKey
output appInsightsConnectionString string = appInsights.outputs.appInsightsConnectionString
output logAnalyticsWorkspaceId string = appInsights.outputs.logAnalyticsWorkspaceId
