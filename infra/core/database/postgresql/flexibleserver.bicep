param name string
param location string = resourceGroup().location
param tags object = {}

param sku object
param storage object
param administratorLogin string
@secure()
param administratorLoginPassword string
param databaseNames array = []
param allowAzureIPsFirewall bool = false
param allowAllIPsFirewall bool = false
param allowedSingleIPs array = []
param administratorLoginPasswordKey string = 'cmsDatabasePassword'
param keyVaultName string

// PostgreSQL version
param version string

// Latest official version 2022-12-01 does not have Bicep types available
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  location: location
  tags: tags
  name: name
  sku: sku
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: storage
    highAvailability: {
      mode: 'Disabled'
    }
  }

  resource database 'databases' = [for databaseName in databaseNames: {
    name: databaseName
  }]

  resource firewall_all 'firewallRules' = if (allowAllIPsFirewall) {
    name: 'allow-all-IPs'
    properties: {
        startIpAddress: '0.0.0.0'
        endIpAddress: '255.255.255.255'
    }
  }

  resource firewall_azure 'firewallRules' = if (allowAzureIPsFirewall) {
    name: 'allow-all-azure-internal-IPs'
    properties: {
        startIpAddress: '0.0.0.0'
        endIpAddress: '0.0.0.0'
    }
  }

  resource firewall_single 'firewallRules' = [for ip in allowedSingleIPs: {
    name: 'allow-single-${replace(ip, '.', '')}'
    properties: {
        startIpAddress: ip
        endIpAddress: ip
    }
  }]

}

resource postgresPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: administratorLoginPasswordKey
  properties: {
    value: administratorLoginPassword
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

output POSTGRES_SERVER_NAME string = postgresServer.name
output POSTGRES_DOMAIN_NAME string = postgresServer.properties.fullyQualifiedDomainName
