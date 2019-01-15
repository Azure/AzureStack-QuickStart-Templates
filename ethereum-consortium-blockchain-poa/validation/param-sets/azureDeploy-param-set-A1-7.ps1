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
  "Tiny-sshPubKey-Standard_A1_A2" = @{
    "namePrefix"                = "ethnet"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_A2"
  };
  "Tiny-sshPubKey-Standard_A3_A4" = @{
    "namePrefix"                = "ethnet"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_A4"
  };
  "Tiny-sshPubKey-Standard_A5_A6" = @{
    "namePrefix"                = "ethnet"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_A6"
  };
  "Tiny-sshPubKey-Standard_A7" = @{
    "namePrefix"                = "ethnet"
    "adminUsername"             = "gethadmin"
    "adminPassword"             = $vmAdminPasswd
    "ethereumAccountPsswd"      = $ethPasswd
    "ethereumAccountPassphrase" = $passphrase
    "ethereumNetworkID"         = $networkID
    "numConsortiumMembers"      = 2
    "numVLNodes"                = 1
    "vlNodeVMSize"              = "Standard_A7"
  };
};