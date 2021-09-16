@description('Name of the VM')
param vmName string

@description('Username for the Virtual Machine. Default value is localadmin')
param adminUsername string = 'ubuntu'

@description('ssh key for vm')
@secure()
param sshkeyData string

@description('Maps to the Image Name')
param imageName string = 'myimage'

@description('uri of the Image ')
param imageUri string = ''

@description('The size of the Virtual Machine.')
param vmSize string = 'Standard_A1'

var publicIPName = 'PublicIP_${vmName}'
var location = resourceGroup().location
var nicName = toLower('nic${uniqueString(resourceGroup().id)}')
var addressPrefix = '10.0.0.0/24'
var subnetName = toLower('subnet${uniqueString(resourceGroup().id)}')
var subnetPrefix = '10.0.0.0/24'
var diagnosticsStorageAccountName = toLower('diag${uniqueString(resourceGroup().id)}')
var virtualNetworkName = toLower('vnet${uniqueString(resourceGroup().id)}')
var vnetID = virtualNetwork.id
var subnetRef = '${vnetID}/subnets/${subnetName}'
var networkSecurityGroupName = toLower('nsg${uniqueString(resourceGroup().id)}')
var sshKeyPath = '/home/${adminUsername}/.ssh/authorized_keys'

resource image 'Microsoft.Compute/images@2017-03-30' = {
  name: imageName
  location: location
  tags: {
    provisioner: 'Image_Deploy'
  }
  properties: {
    storageProfile: {
      osDisk: {
        osType: 'Linux'
        osState: 'Generalized'
        blobUri: imageUri
        storageAccountType: 'Standard_LRS'
        caching: 'ReadWrite'
        diskSizeGB: 127
      }
    }
  }
}

resource diagnosticsStorageAccount 'Microsoft.Storage/storageAccounts@2017-10-01' = {
  name: diagnosticsStorageAccountName
  location: location
  properties: {}
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2017-10-01' = {
  name: networkSecurityGroupName
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'ssh'
        properties: {
          description: 'Allow ssh'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2017-10-01' = {
  name: virtualNetworkName
  location: location
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
        }
      }
    ]
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2017-10-01' = {
  name: publicIPName
  location: location
  tags: {
    provisioner: 'image_deploy'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2017-10-01' = {
  name: nicName
  location: location
  properties: {
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetRef
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2017-03-30' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: sshKeyPath
              keyData: sshkeyData
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        id: image.id
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(diagnosticsStorageAccount.id, providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).primaryEndpoints.blob
      }
    }
  }
}
