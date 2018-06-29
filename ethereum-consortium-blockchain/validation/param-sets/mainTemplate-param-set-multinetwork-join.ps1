# Params for mainTemplate.json
echo "Loading param sets for canary validation of Azure Marketplace template"

$localPeers=2;

$paramSet = @{
  "JoiningMemberA" = @{
    "namePrefix"                = GeneratePrefix;
    "authType"                  = $authType;
    "adminUsername"             = "gethadmin";
    "adminPassword"             = $vmAdminPasswd;
    "adminSSHKey"               = $sshPublicKey;
    "ethereumAccountPsswd"      = $ethPasswd+"1";
    "ethereumAccountPassphrase" = $passphrase+"1";
	"consortiumMemberId"        = 1;
    "numMiningNodes"            = $localPeers;
    "mnNodeVMSize"              = "Standard_D1";
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1;
    "txNodeVMSize"              = "Standard_D1";
    "txStorageAccountType"      = "Standard_LRS";
    "location"                  = $LOCATION;
    "baseUrl"                   = $BASE_URL;
	"consortiumData"            = $consortiumDataA;
	"consortiumMemberGateway"   = $gatewayIdA;
	"connectionSharedKey"       = $sharedKeyA;
  };
  "JoiningMemberB" = @{
    "namePrefix"                = GeneratePrefix;
    "authType"                  = $authType;
    "adminUsername"             = "gethadmin";
    "adminPassword"             = $vmAdminPasswd;
    "adminSSHKey"               = $sshPublicKey;
    "ethereumAccountPsswd"      = $ethPasswd+"100";
    "ethereumAccountPassphrase" = $passphrase+"100";
	"consortiumMemberId"        = 100;
    "numMiningNodes"            = $localPeers;
    "mnNodeVMSize"              = "Standard_D1";
    "mnStorageAccountType"      = "Standard_LRS"
    "numTXNodes"                = 1;
    "txNodeVMSize"              = "Standard_D1";
    "txStorageAccountType"      = "Standard_LRS";
    "location"                  = $LOCATION;
    "baseUrl"                   = $BASE_URL;
	"consortiumData"            = $consortiumDataB;
	"consortiumMemberGateway"   = $gatewayIdB;
	"connectionSharedKey"       = $sharedKeyB;
  };
};