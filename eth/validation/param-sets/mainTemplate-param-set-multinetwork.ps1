# Params for mainTemplate.json
echo "Loading param sets for canary validation of Azure Marketplace template"

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

if ([string]::IsNullOrEmpty($namePrefix))
{ 
	$namePrefix = GeneratePrefix
}

$genesisBlock = '{   "alloc": {     "Aee0E6006F3DA8c596cAf84A7c599Cc2e919aeC0": {       "balance": "1000000000000000000000000000000"     }   },   "nonce": "0x0000000000000042",   "difficulty": "0x6666",   "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",   "coinbase": "0x0000000000000000000000000000000000000000",   "timestamp": "0x00",   "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",   "extraData": "0x11bbe8db4e347b4e8c937c1c8370e4b5ed33adb3db69cbdb7a38e1e50b1b82fa",   "gasLimit": "0x4c4b40" }';

$paramSet = @{
  "SshWithGenesisBlock" = @{
    "namePrefix"                = $namePrefix;
    "authType"                  = "sshPublicKey";
    "adminUsername"             = "gethadmin";
    "adminPassword"             = $vmAdminPasswd;
    "adminSSHKey"               = $sshPublicKey;
    "ethereumAccountPsswd"      = "";
    "ethereumAccountPassphrase" = "";
    "ethereumNetworkID"         = $networkID;
	"consortiumMemberId"        = 0;
    "numMiningNodes"            = 2;
    "mnNodeVMSize"              = "Standard_D1";
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1;
    "txNodeVMSize"              = "Standard_D1";
    "txStorageAccountType"      = "Standard_LRS";
    "location"                  = $LOCATION;
    "baseUrl"                   = $BASE_URL;
	"genesisBlock"              = $genesisBlock;
  };
  "PasswordWithPassphrase" = @{
    "namePrefix"                = $namePrefix;
    "authType"                  = $authType;
    "adminUsername"             = "gethadmin";
    "adminPassword"             = $vmAdminPasswd;
    "adminSSHKey"               = $sshPublicKey;
    "ethereumAccountPsswd"      = $ethPasswd;
    "ethereumAccountPassphrase" = $passphrase;
    "ethereumNetworkID"         = $networkID;
	"consortiumMemberId"        = 0;
    "numMiningNodes"            = 2;
    "mnNodeVMSize"              = "Standard_D1";
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1;
    "txNodeVMSize"              = "Standard_D1";
    "txStorageAccountType"      = "Standard_LRS";
    "location"                  = $LOCATION;
    "baseUrl"                   = $BASE_URL;
  };
};