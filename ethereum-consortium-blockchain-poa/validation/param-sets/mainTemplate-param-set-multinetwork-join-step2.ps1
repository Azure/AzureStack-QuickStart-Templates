# Params for mainTemplate.json
echo "Loading param sets for canary validation of Azure Marketplace template"

$localPeers=2;

$paramSet = @{
  "JoiningMemberY" = @{
    "namePrefix"                = GeneratePrefix;
    "authType"                  = $authType;
    "adminUsername"             = "gethadmin";
    "adminPassword"             = $vmAdminPasswd;
    "adminSSHKey"               = $sshPublicKey;
    "ethereumAccountPsswd"      = $ethPasswd+"99";
    "ethereumAccountPassphrase" = $passphrase+"99";
	"consortiumMemberId"        = 99;
    "numVLNodes"                = 1;
    "vlNodeVMSize"              = "Standard_D1";
    "vlStorageAccountType"      = "Standard_LRS";
    "location"                  = $LOCATION;
    "baseUrl"                   = $BASE_URL;
	"consortiumData"            = $consortiumDataY;
	"consortiumMemberGateway"   = $gatewayIdY;
	"connectionSharedKey"       = $sharedKeyY;
  };
  "JoiningMemberZ" = @{
    "namePrefix"                = GeneratePrefix;
    "authType"                  = $authType;
    "adminUsername"             = "gethadmin";
    "adminPassword"             = $vmAdminPasswd;
    "adminSSHKey"               = $sshPublicKey;
    "ethereumAccountPsswd"      = $ethPasswd+"101";
    "ethereumAccountPassphrase" = $passphrase+"101";
	"consortiumMemberId"        = 101;
    "numVLNodes"                = 1;
    "vlNodeVMSize"              = "Standard_D1";
    "vlStorageAccountType"      = "Standard_LRS";
    "location"                  = $LOCATION;
    "baseUrl"                   = $BASE_URL;
	"consortiumData"            = $consortiumDataB;
	"consortiumMemberGateway"   = $gatewayIdB;
	"connectionSharedKey"       = $sharedKeyB;
  };
};