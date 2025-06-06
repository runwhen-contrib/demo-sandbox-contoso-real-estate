param name string
param location string = resourceGroup().location
param tags object = {}

@secure()
param adminJwtSecret string
@secure()
param apiTokenSalt string
@secure()
param appKeys string
param applicationInsightsName string
param databaseHost string
param databaseName string = 'strapi'
@secure()
param databasePassword string
param databaseUsername string = 'contoso'
param cmsImageName string = ''
@secure()
param jwtSecret string
param keyVaultName string
param serviceName string = 'cms'
param storageAccountName string
param storageContainerName string

// Outputs for App Service Web App
output SERVICE_CMS_URI string = webApps.outputs.cmsWebAppUri
