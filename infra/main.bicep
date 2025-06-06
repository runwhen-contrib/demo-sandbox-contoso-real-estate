targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

param apimServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param cosmosAccountName string = ''
param cosmosDatabaseName string = ''
param keyVaultName string = ''
param logAnalyticsName string = ''
param webServiceName string = ''
param storageAccountName string = ''
param storageContainerName string = ''
param stripeServiceUrl string = ''

// Set to true to use Azure API Management
@description('Flag to use Azure API Management to mediate the calls between the Web frontend and the backend API')
param useAPIM bool = false

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

/////////// Common ///////////

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    allowBlobPublicAccess: true
    location: location
    containers: [
      {
        name: !empty(storageContainerName) ? storageContainerName : 'stc${resourceToken}'
        publicAccess: 'Blob'
      }
    ]
  }
}

// Creates Azure API Management (APIM) service to mediate the requests between the frontend and the backend API
module apim './core/gateway/apim.bicep' = if (useAPIM) {
  name: 'apim'
  scope: rg
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    sku: 'Consumption'
  }
}

// Configures the API in the Azure API Management (APIM) service
module apimApi './app/apim-api.bicep' = if (useAPIM) {
  name: 'apim-api'
  scope: rg
  params: {
    name: useAPIM ? apim.outputs.apimServiceName : ''
    apiName: 'contoso-api'
    apiDisplayName: 'contoso-api'
    apiDescription: 'This is the API integration server for Contoso Real Estate company.'
    apiPath: 'api'
    webFrontendUrl: portal.outputs.SERVICE_WEB_URI
    apiBackendUrl: api.outputs.SERVICE_API_URI
  }
}

// Configures the API in the Azure API Management (APIM) service
module apimStripe './app/apim-stripe.bicep' = if (useAPIM) {
  name: 'apim-stripe'
  scope: rg
  params: {
    name: useAPIM ? apim.outputs.apimServiceName : ''
    apiName: 'contoso-stripe'
    apiDisplayName: 'contoso-stripe'
    apiDescription: 'This is the Stripe integration server for Contoso Real Estate company.'
    apiPath: 'stripe'
    webFrontendUrl: portal.outputs.SERVICE_WEB_URI
    apiBackendUrl: webApps.outputs.stripeWebAppUri
  }
}

/////////// Portal ///////////

// The application frontend
module portal './app/portal.bicep' = {
  name: 'portal'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webStaticSites}web-${resourceToken}'
    location: location
    tags: tags
  }
}

// the linked APIM or Function API
module portalBackend './app/portal-backend.bicep' = {
  name: 'portal-apim'
  scope: rg
  params: {
    name: useAPIM ? apim.outputs.apimServiceName : webApps.outputs.blogWebAppName
    location: location
    tags: tags
    useAPIM: useAPIM
    portalName: portal.outputs.SERVICE_WEB_NAME
    apiServiceName: webApps.outputs.blogWebAppName
  }
}


// the realt-time notification integration
module notifications 'app/notifications.bicep' = {
  name: 'notifications'
  scope: rg
  params: {
    name: !empty(notificationsServiceName) ? notificationsServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    tags: tags
  }
}

module notificationsBackend 'app/notifications-backend.bicep' = {
  name: 'notifications-backend'
  scope: rg
  params: {
    name: !empty(notificationsServiceName) ? notificationsServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    tags: tags
    containerRegistryName: containerRegistryName
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    serviceName: notificationsServiceName
    notificationsImageName: notificationsImageName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    notificationsServiceName: notifications.outputs.SERVICE_WEBPUBSUB_NAME
    keyVaultName: keyVault.outputs.name
  }
}

// The application database
module cosmos './app/db.bicep' = {
  name: 'cosmos'
  scope: rg
  params: {
    accountName: !empty(cosmosAccountName) ? cosmosAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    databaseName: cosmosDatabaseName
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
  }
}

/////////// Portal API ///////////

// Create App Service Plan for Web Apps
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    kind: 'linux'
    reserved: true
    sku: {
      name: 'S1'
      tier: 'Standard'
      size: 'S1'
      family: 'S'
      capacity: 1
    }
  }
}

// Create Web Apps (Blog, CMS, Stripe)
module webApps './core/host/webapps.bicep' = {
  name: 'webapps'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}${resourceToken}'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    appInsightsName: monitoring.outputs.applicationInsightsName
    appInsightsKey: monitoring.outputs.applicationInsightsInstrumentationKey
    keyVaultName: keyVault.outputs.name
  }
}

// Configure auto-scaling for the App Service Plan
module autoscale './core/host/autoscale.bicep' = {
  name: 'autoscale'
  scope: rg
  params: {
    name: 'app'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    appServicePlanName: appServicePlan.outputs.id
  }
}

// Restore required parameters
param notificationsServiceName string = ''
param notificationsImageName string = ''
param appServicePlanName string = ''
param apiServiceName string = ''
param cmsDatabaseServerName string = ''
param cmsDatabaseUser string = ''
@secure()
param cmsDatabasePassword string
param cmsDatabaseName string = 'cms'
param eventGridName string = ''

// Update api module's appSettings to use these parameters
module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}api-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    eventGridName: eventGrid.name
    storageAccountName: storageAccount.outputs.name
    allowedOrigins: [ portal.outputs.SERVICE_WEB_URI ]
    appSettings: {
      AZURE_COSMOS_CONNECTION_STRING_KV: cosmos.outputs.connectionStringKey
      AZURE_COSMOS_CONNECTION_STRING_KEY: cosmos.outputs.connectionString
      AZURE_COSMOS_DATABASE_NAME: cosmos.outputs.databaseName
      AZURE_COSMOS_ENDPOINT: cosmos.outputs.endpoint
      STRAPI_DATABASE_NAME: cmsDatabaseName
      STRAPI_DATABASE_USERNAME: cmsDatabaseUser
      STRAPI_DATABASE_PASSWORD: cmsDatabasePassword
      STRAPI_DATABASE_HOST: cmsDB.outputs.POSTGRES_DOMAIN_NAME
      STRAPI_DATABASE_PORT: '5432'
      STRAPI_DATABASE_SSL: 'true'
    }
    stripeServiceUrl: stripeServiceUrl
  }
}

/////////// CMS ///////////

// Remove or comment out the old container app modules for blog, cms, and stripe
// module cms './app/cms.bicep' = { ... }
// module stripe './app/stripe.bicep' = { ... }

// // The cms database
module cmsDB './core/database/postgresql/flexibleserver.bicep' = {
  name: 'postgresql'
  scope: rg
  params: {
    name: !empty(cmsDatabaseServerName) ? cmsDatabaseServerName : '${abbrs.dBforPostgreSQLServers}db-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'Standard_B1ms'
      tier: 'Burstable'
    }
    storage: {
      storageSizeGB: 32
    }
    version: '13'
    administratorLogin: cmsDatabaseUser
    administratorLoginPassword: cmsDatabasePassword
    databaseNames: [ cmsDatabaseName ]
    allowAzureIPsFirewall: true
    keyVaultName: keyVault.outputs.name
  }
}

/////////// Blog ///////////

// Remove or comment out the old container app modules for blog, cms, and stripe
// module blog './app/blog.bicep' = { ... }

/////////// Payment API ///////////

// Remove or comment out the old container app modules for blog, cms, and stripe
// module stripe './app/stripe.bicep' = { ... }

module eventGrid './app/events.bicep' = {
  name: 'events'
  scope: rg
  params: {
    name: !empty(eventGridName) ? eventGridName : '${abbrs.eventGridDomainsTopics}${resourceToken}'
    location: location
    tags: tags
    storageAccountName: storageAccount.outputs.name
  }
}

// Add container registry module before the API module
module containerRegistry './core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// Update containerRegistryName to use the output from container registry
var containerRegistryName = containerRegistry.outputs.name

// Add Container Apps environment for notifications backend
module containerAppsEnvironment './core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
}

// Data outputs
output AZURE_COSMOS_CONNECTION_STRING_KEY string = cosmos.outputs.connectionStringKey
output AZURE_COSMOS_DATABASE_NAME string = cosmos.outputs.databaseName

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName

output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId

output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output SERVICE_WEB_NAME string = portal.outputs.SERVICE_WEB_NAME

output USE_APIM bool = useAPIM

output SERVICE_API_ENDPOINTS array = useAPIM ? [ apimApi.outputs.SERVICE_API_URI, api.outputs.SERVICE_API_URI ] : [api.outputs.SERVICE_API_URI]

output SERVICE_WEB_URI string = portal.outputs.SERVICE_WEB_URI
output SERVICE_BLOG_URI string = webApps.outputs.blogWebAppUri
output SERVICE_CMS_URI string = webApps.outputs.cmsWebAppUri
output SERVICE_STRIPE_URI string = webApps.outputs.stripeWebAppUri
output STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name
output STORAGE_CONTAINER_NAME string = storageContainerName
output SERVICE_CMS_SERVER_HOST string = cmsDB.outputs.POSTGRES_DOMAIN_NAME

output SERVICE_WEBPUBSUB_NAME string = notifications.outputs.SERVICE_WEBPUBSUB_NAME
output SERVICE_WEBPUBSUB_URI string = notificationsBackend.outputs.SERVICE_WEBPUBSUB_URI

// Additional outputs for portal predeploy script
output SERVICE_WEB_PUB_SUB_URL string = notificationsBackend.outputs.SERVICE_WEBPUBSUB_URI  
output SERVICE_WEB_PUB_SUB_PATH string = '/eventhandler'
