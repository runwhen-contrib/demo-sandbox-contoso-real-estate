param name string
param location string = resourceGroup().location
param tags object = {}

param appServicePlanId string
param appInsightsName string
param appInsightsKey string
param keyVaultName string = ''

// Blog Web App
module blogWebApp 'appservice.bicep' = {
  name: '${name}-blog-webapp'
  params: {
    name: '${name}-blog'
    location: location
    tags: union(tags, { 'azd-service-name': 'blog' })
    appServicePlanId: appServicePlanId
    runtimeName: 'node'
    runtimeVersion: '18-lts'
    applicationInsightsName: appInsightsName
    keyVaultName: keyVaultName
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsKey
      WEBSITE_NODE_DEFAULT_VERSION: '~18'
      WEBSITE_RUN_FROM_PACKAGE: '1'
    }
  }
}

// CMS Web App
module cmsWebApp 'appservice.bicep' = {
  name: '${name}-cms-webapp'
  params: {
    name: '${name}-cms'
    location: location
    tags: union(tags, { 'azd-service-name': 'cms' })
    appServicePlanId: appServicePlanId
    runtimeName: 'node'
    runtimeVersion: '18-lts'
    applicationInsightsName: appInsightsName
    keyVaultName: keyVaultName
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsKey
      WEBSITE_NODE_DEFAULT_VERSION: '~18'
      WEBSITE_RUN_FROM_PACKAGE: '1'
    }
  }
}

// Stripe Web App
module stripeWebApp 'appservice.bicep' = {
  name: '${name}-stripe-webapp'
  params: {
    name: '${name}-stripe'
    location: location
    tags: union(tags, { 'azd-service-name': 'stripe' })
    appServicePlanId: appServicePlanId
    runtimeName: 'node'
    runtimeVersion: '18-lts'
    applicationInsightsName: appInsightsName
    keyVaultName: keyVaultName
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsKey
      WEBSITE_NODE_DEFAULT_VERSION: '~18'
      WEBSITE_RUN_FROM_PACKAGE: '1'
    }
  }
}

output blogWebAppName string = blogWebApp.outputs.name
output blogWebAppUri string = blogWebApp.outputs.uri
output cmsWebAppName string = cmsWebApp.outputs.name
output cmsWebAppUri string = cmsWebApp.outputs.uri
output stripeWebAppName string = stripeWebApp.outputs.name
output stripeWebAppUri string = stripeWebApp.outputs.uri 