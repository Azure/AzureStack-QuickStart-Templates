@description('Size of VMs in the VM Scale Set.')
param vmSku string = 'Standard_D1'

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version. Allowed values: 2008-R2-SP1, 2012-Datacenter, 2012-R2-Datacenter.')
@allowed([
  '2012-R2-Datacenter'
  '2016-Datacenter-Server-Core'
  '2016-Datacenter'
])
param osImageSku string = '2016-Datacenter'

@description('Maps to the publisher in the Azure Stack Platform Image Repository manifest file.')
param osImagePublisher string = 'MicrosoftWindowsServer'

@description('Maps to the Offer in the Azure Stack Platform Image Repository manifest file.')
param osImageOffer string = 'WindowsServer'

@description('String used as a base for naming resources. Must be 3-10 characters in length and globally unique across Azure Stack. A hash is prepended to this string for some resources, and resource-specific information is appended.')
@minLength(3)
@maxLength(10)
param vmssName string = substring('vmss${uniqueString(replace(resourceGroup().id, '-', ''))}', 0, 8)

@description('Number of VM instances (20 or less).')
@maxValue(20)
param instanceCount int = 2

@description('Admin username on all VMs.')
param adminUsername string = 'azureuser'

@description('Admin password on all VMs.')
@secure()
param adminPassword string = 'Subscription#${subscription().subscriptionId}'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = 'https://raw.githubusercontent.com/Azure/azurestack-quickstart-templates/master/201-vmss-windows-extension'

var location = resourceGroup().location
var vnetName = toLower('vnet${uniqueString(resourceGroup().id)}')
var subnetName = toLower('subnet${uniqueString(resourceGroup().id)}')
var storageAccountName = toLower('SA${uniqueString(resourceGroup().id)}')
var storageAccountContainerName = toLower('SC${uniqueString(resourceGroup().id)}')
var storageAccountType = 'Standard_LRS'
var OSDiskName = 'osdisk'
var vnetID = vnet.id
var subnetRef = '${vnetID}/subnets/${subnetName}'
var publicIPAddressName = toLower('pip${uniqueString(resourceGroup().id)}')
var vmssDomainName = toLower('pubdns${uniqueString(resourceGroup().id)}')
var loadBalancerName = 'LB${uniqueString(resourceGroup().id)}'
var loadBalancerFrontEndName = 'LBFrontEnd${uniqueString(resourceGroup().id)}'
var loadBalancerBackEndName = 'LBBackEnd${uniqueString(resourceGroup().id)}'
var loadBalancerProbeName = 'LBHttpProbe${uniqueString(resourceGroup().id)}'
var loadBalancerNatPoolName = 'LBNatPool${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
}

resource vnet 'Microsoft.Network/virtualNetworks@2018-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2018-11-01' = {
  name: publicIPAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: vmssDomainName
    }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2018-11-01' = {
  name: loadBalancerName
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: loadBalancerFrontEndName
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: loadBalancerBackEndName
      }
    ]
    loadBalancingRules: [
      {
        name: 'roundRobinLBRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, loadBalancerFrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, loadBalancerProbeName)
          }
        }
      }
    ]
    probes: [
      {
        name: loadBalancerProbeName
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    inboundNatPools: [
      {
        name: loadBalancerNatPoolName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, loadBalancerFrontEndName)
          }
          protocol: 'Tcp'
          frontendPortRangeStart: 50000
          frontendPortRangeEnd: 50019
          backendPort: 3389
        }
      }
    ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  name: vmssName
  location: location
  properties: {
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          vhdContainers: [
            '${reference(storageAccount.id, providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).primaryEndpoints.blob}${storageAccountContainerName}'
          ]
          name: OSDiskName
          caching: 'ReadOnly'
          createOption: 'FromImage'
        }
        imageReference: {
          publisher: osImagePublisher
          offer: osImageOffer
          sku: osImageSku
          version: 'latest'
        }
      }
      osProfile: {
        computerNamePrefix: vmssName
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetRef
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: loadBalancer.properties.backendAddressPools[0].id
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: loadBalancer.properties.inboundNatPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'customScript'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              settings: {
                fileUris: [
                  '${artifactsLocation}/scripts/helloWorld.ps1'
                ]
              }
              typeHandlerVersion: '1.8'
              autoUpgradeMinorVersion: true
              protectedSettings: {
                commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File helloWorld.ps1'
              }
            }
          }
        ]
      }
    }
  }
}
