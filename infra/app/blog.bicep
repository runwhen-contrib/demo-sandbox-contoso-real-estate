param name string
param location string = resourceGroup().location
param tags object = {}

param applicationInsightsName string
param cmsUrl string
param portalUrl string
param keyVaultName string
param serviceName string = 'blog'

// Outputs for App Service Web App
output SERVICE_BLOG_URI string = webApps.outputs.blogWebAppUri
