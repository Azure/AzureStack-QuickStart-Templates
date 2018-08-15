# Params for mainTemplate.json
echo "Loading VM size parameter set for mainTemplate.json"

# Plese define the following variables in your personal automated-validation script
#$location       = <SET TO DESIRED AZURE REGION>;
#$baseUrl        = <SET TO BASE FOLDER LOCATION OF TEMPLTE FILE>;
#$authType       = <SET TO EITHER password or sshPublicKey>;
#$vmAdminPasswd  = <SET TO DESIRED PASSWORD>;
#$ethPasswd      = <SET TO DESIRED PASSWORD>;
#$passphrase     = <SET TO DESIRED PASSPHRASE>;
#$sshPublicKey   = <SET TO YOUR SSH PUBLIC KEY>;

# Some overridable defaults
# These sizes are only available in East US, West US, North Central US and South Central US per https://azure.microsoft.com/en-us/regions/services/
if ([string]::IsNullOrEmpty($location))
{ $location = "North Central US"; }

if (!$networkID)
{ $networkID = 10101; }

if ([string]::IsNullOrEmpty($authType))
{ $authType = "password"; }

$paramSet = @{
  "Tiny-Standard_A8_A9" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numMiningNodesPerMember"   = 1
    "mnNodeVMSize"              = "Standard_A8"
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1
    "txNodeVMSize"              = "Standard_A9"
    "txStorageAccountType"      = "Standard_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_A10_A11" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numMiningNodesPerMember"   = 1
    "mnNodeVMSize"              = "Standard_A10"
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1
    "txNodeVMSize"              = "Standard_A11"
    "txStorageAccountType"      = "Standard_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  }
};