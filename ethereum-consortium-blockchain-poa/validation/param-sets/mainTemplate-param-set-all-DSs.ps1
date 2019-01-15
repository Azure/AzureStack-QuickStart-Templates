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
if ([string]::IsNullOrEmpty($location))
{ $location = "centralus"; }

if (!$networkID)
{ $networkID = 10101; }

if ([string]::IsNullOrEmpty($authType))
{ $authType = "password"; }

$paramSet = @{
  "Tiny-Standard_DS1_DS2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS2"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS3_DS4" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS4"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS11_DS12" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS12"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS13_DS14" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS14"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS1_v2_DS2_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS2_v2"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS3_v2_DS4_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS4_v2"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS5_v2_DS11_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS11_v2"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS12_v2_DS13_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS13_v2"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  };
  "Tiny-Standard_DS14_v2_DS15_v2" = @{
    "namePrefix"                = "ethnet"
    "authType"                  = $authType
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "adminSSHKey"               = $sshPublicKey
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_DS15_v2"
    "vlStorageAccountType"      = "Premium_LRS"
    "location"                  = $location
    "baseUrl"                   = $baseUrl
  }
};