@description('The name of the Administrator of the new VMs')
param adminUsername string = 'vmadmin'

@description('The password for the Administrator account of the new VMs. Default value is subscription id')
@secure()
param adminPassword string = 'Subscription#${substring(resourceGroup().id, 15, 36)}'

@description('Number of VMs to deploy, limit 5 since this sample is using a single storage account')
@allowed([
  2
  3
  4
  5
])
param numberOfInstances int = 3

@description('Size of the Data Disk')
@allowed([
  100
  500
  750
  1000
])
param dataDiskSize int = 1000

@description('VM name prefix')
param vmNamePrefix string = 'vmset-'

@description('This is the size of your VM')
@allowed([
  'Standard_A1'
  'Standard_A2'
  'Standard_A3'
  'Standard_A4'
  'Standard_D1'
  'Standard_D2'
  'Standard_D3'
  'Standard_D4'
])
param vmSize string = 'Standard_A1'

@description('dns name prefix')
param dnsPrefix string = 'vmdns'

@description('Maps to the publisher in the Azure Stack Platform Image Repository manifest file.')
param osImagePublisher string = 'Canonical'

@description('Maps to the Offer in the Azure Stack Platform Image Repository manifest file.')
param osImageOffer string = 'UbuntuServer'

@description('The Linux version for the VM. This will pick a fully patched image of this given Centos')
@allowed([
  'Centos-7.4'
  '16.04-LTS'
])
param osImageSKU string = '16.04-LTS'

var availabilitySetName = toLower('aSet-${resourceGroup().name}')
var storageAccountType = 'Standard_LRS'
var osImageVersion = 'latest'
var addressPrefix = '10.0.0.0/16'
var virtualNetworkName = toLower('vNet-${resourceGroup().name}')
var NICPrefix = 'vnic-'
var subnetPrefix = '10.0.0.0/24'
var subnetName = 'vmstaticsubnet'
var storageName = 'sa${uniqueString(resourceGroup().id)}'
var publicLBName = toLower('external-lb-${resourceGroup().name}')
var lbFE = toLower('external-lb-fe-${resourceGroup().name}')
var publicIPAddressName = toLower('public-ip${resourceGroup().name}')
var nsgName = toLower('vmnsg${resourceGroup().name}')
var vmContainerName = 'vhds'

resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageName
  location: resourceGroup().location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  dependsOn: [
    publicLB
  ]
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2018-11-01' = {
  name: nsgName
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'rule1'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2020-06-01' = {
  name: availabilitySetName
  location: resourceGroup().location
  properties: {
    platformFaultDomainCount: 1
    platformUpdateDomainCount: 1
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2018-11-01' = {
  name: publicIPAddressName
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: dnsPrefix
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2018-11-01' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicLB 'Microsoft.Network/loadBalancers@2018-11-01' = {
  name: publicLBName
  location: resourceGroup().location
  properties: {
    frontendIPConfigurations: [
      {
        name: lbFE
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LoadBalancerBackend'
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource inboundNatRule 'Microsoft.Network/loadBalancers/inboundNatRules@2018-11-01' = [for i in range(0, numberOfInstances): {
  name: '${publicLBName}/ssh-VM${i}'
  properties: {
    frontendIPConfiguration: {
      id: publicLB.properties.frontendIPConfigurations[0].id
    }
    protocol: 'Tcp'
    frontendPort: (i + 2200)
    backendPort: 22
    enableFloatingIP: false
  }
}]

resource networkInterface 'Microsoft.Network/networkInterfaces@2018-11-01' = [for i in range(0, numberOfInstances): {
  name: '${NICPrefix}${vmNamePrefix}${i}'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          loadBalancerBackendAddressPools: [
            {
              id: publicLB.properties.backendAddressPools[0].id
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: inboundNatRule[i].id
            }
          ]
        }
      }
    ]
  }
}]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2020-06-01' = [for i in range(0, numberOfInstances): {
  name: '${vmNamePrefix}${i}'
  location: resourceGroup().location
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: osImagePublisher
        offer: osImageOffer
        sku: osImageSKU
        version: osImageVersion
      }
      osDisk: {
        name: 'osdisk'
        vhd: {
          uri: '${reference('Microsoft.Storage/storageAccounts/${storageName}', providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).primaryEndpoints.blob}${vmContainerName}/${vmNamePrefix}${i}-osdisk.vhd'
        }
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          vhd: {
            uri: '${reference('Microsoft.Storage/storageAccounts/${storageName}', providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).primaryEndpoints.blob}${vmContainerName}/${vmNamePrefix}${i}-data-1.vhd'
          }
          name: '${vmNamePrefix}${i}-data-disk1'
          createOption: 'Empty'
          caching: 'None'
          diskSizeGB: dataDiskSize
          lun: 0
        }
        {
          vhd: {
            uri: '${reference('Microsoft.Storage/storageAccounts/${storageName}', providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).primaryEndpoints.blob}${vmContainerName}/${vmNamePrefix}${i}-data-2.vhd'
          }
          name: '${vmNamePrefix}${i}-data-disk2'
          createOption: 'Empty'
          caching: 'None'
          diskSizeGB: dataDiskSize
          lun: 1
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: concat(reference('Microsoft.Storage/storageAccounts/${storageName}', providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).primaryEndpoints.blob)
      }
    }
  }
  dependsOn: [
    storage
  ]
}]
