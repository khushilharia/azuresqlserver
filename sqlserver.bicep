@description('SQL server name')
param sqlServerName string

@description('SQL admin username')
param administratorLogin string

@secure()
@description('SQL admin password')
param administratorPassword string

@description('Location of the deployment')
param location string = resourceGroup().location

@description('Name of existing VNet')
param vnetName string

@description('Name of the existing subnet to host the private endpoint')
param subnetName string

@description('Name of the resource group where the VNet lives (can be same or different RG)')
param vnetResourceGroup string = resourceGroup().name

// @description('Private DNS zone for privatelink.database.windows.net (optional)')
// param privateDnsZoneId string = ''

// Reference the existing virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

// Reference the existing subnet within that VNet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: subnetName
  parent: vnet
}

// Create SQL Server
resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: '12.0'
  }
}

// Private Endpoint
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${sqlServerName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlserverConnection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [ 'sqlServer' ]
        }
      }
    ]
  }
}

// Optional: Private DNS Zone Group
// resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (privateDnsZoneId != '') {
//   parent: sqlPrivateEndpoint
//   name: 'sql-dns-zone-group'
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'sqlZoneConfig'
//         properties: {
//           privateDnsZoneId: privateDnsZoneId
//         }
//       }
//     ]
//   }
// }

// ==============================================================================================================

@description('Name of the SQL Database to create')
param sqlDatabaseName string

@description('SKU of the SQL Database')
param skuName string = 'S0'

@description('Max size in bytes')
param maxSizeBytes string = '2147483648'

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

// SQL Database creation
resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    maxSizeBytes: maxSizeBytes
  }
}

// Diagnostics settings for the DB
resource dbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlDatabaseName}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

