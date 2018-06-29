# Params for mainTemplate.json
echo "Loading happy path parameter set for mainTemplate.json"

# Plese define the following variables in your personal automated-validation script
#$location       = <SET TO DESIRED AZURE REGION>;
#$baseUrl        = <SET TO BASE FOLDER LOCATION OF TEMPLTE FILE>;
#$authType       = <SET TO EITHER password or sshPublicKey>;
#$vmAdminPasswd  = <SET TO DESIRED PASSWORD>;
#$ethPasswd      = <SET TO DESIRED PASSWORD>;
#$passphrase     = <SET TO DESIRED PASSPHRASE>;
#$sshPublicKey   = <SET TO YOUR SSH PUBLIC KEY>;

# Some overridable defaults
if ([string]::IsNullOrEmpty($location))
{ $location = "centralus"; }

if (!$networkID)
{ $networkID = 10101; }

$paramSet = @{
  "Tiny-Passwd-Standard_LRS-A1" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = "password"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = ""
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numMiningNodesPerMember"   = 1
    "mnNodeVMSize"              = "Standard_A1"
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1
    "txNodeVMSize"              = "Standard_A1"
    "txStorageAccountType"      = "Standard_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-sshPubKey-Standard_GRS-F1" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = "sshPublicKey"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = ""
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numMiningNodesPerMember"   = 1
    "mnNodeVMSize"              = "Standard_F1"
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1
    "txNodeVMSize"              = "Standard_F1"
    "txStorageAccountType"      = "Standard_GRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Small-Passwd-Standard_RAGRS-D1_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = "password"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = ""
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numMiningNodesPerMember"   = 2
    "mnNodeVMSize"              = "Standard_D1_v2"
    "mnStorageAccountType"      = "Standard_RAGRS"
    "numTXNodes"                = 2
    "txNodeVMSize"              = "Standard_D1_v2"
    "txStorageAccountType"      = "Standard_RAGRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Small-sshPubKey-Premium_LRS-DS1_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = "sshPublicKey"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = ""
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numMiningNodesPerMember"   = 2
    "mnNodeVMSize"              = "Standard_DS1_v2"
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 2
    "txNodeVMSize"              = "Standard_DS1_v2"
    "txStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  }
};