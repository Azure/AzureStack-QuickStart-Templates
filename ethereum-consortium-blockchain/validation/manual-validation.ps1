#####
# IMPORTANT: !!!!! Ensure the password is set outside of this script to prevent a secret from being checked into the repo accidentally !!!!!
#
# ===== Instructions =====
# 1. Set SUBSCRIPTION_ID to where you want to deploy into.
# 2. Set $PARAMS_FILE_PATH to the location of the parameters powershell file (e.g. "mainTemplate-param-set-happy-path.ps1").  
#      Be sure to set all variables needed by the param file before loading it!
# 3. Set $LOCATION to the desired Azure region where the resource group will be created (e.g. "Central US" or "centralus")
# 4. Set the TEMPLATE_URI to the location of the deployment template json file - should be reachable without any authentication. 
#      The template specified should be of a type that matches the parameters specified in #2 (quickstart, marketplace templates 
#      have different parameter sets)
# 5. On first run, you will be asked to login.  Login with your account that has access to the Key Vault containig the password
#      of the service principle that the workflow will be run as.
#
# Note: Instructions to setup service principle were sourced from http://blog.davidebbo.com/2014/12/azure-service-principal.html
#####

#####
# Deployment specific variables 
#####
# Subscription under which resources will be deployed
$SUBSCRIPTION_ID          = "922bb5fb-9ac3-4aa7-9a6b-f965aa49e6a3";
$LOCATION                 = "eastus";
$BASE_URL                 = "https://gallery.azure.com/artifact/20161101/microsoft-azure-blockchain.azure-multi-member-blockchain-service-previewethereum-consortium-leader.1.0.1/Artifacts"; # Specify this for marketplace deployments
$TEMPLATE_URI             = $BASE_URL+"/mainTemplate.json"; # either mainTemplate.json for marketplace or azureDeploy.json for quickstart
# Append timestamp so each run creates a unique resource group name
$RESOURCE_GROUP_NAME_PREFIX = "gproano"+"-"+"test"+"-"+(Get-Date ([TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::UTC)) -UFormat %Y-%m-%d_%H.%M.%SZ-);

#####
# Template params global values
#####
$PARAMS_FILE_PATH = $PSScriptRoot+"\param-sets\mainTemplate-param-set-multinetwork.ps1";
# !!! Set all mandatory variables used in the params file here !!!
$baseUrl        = $BASE_URL # (location of artifacts that are being validated, set to folder path of template file)
$location       = $LOCATION;
$authType      = "password";
$vmAdminPasswd = "Test-3212017";
$sshPublicKey  = "";
$ethPasswd     = "Test-3212017";
$passphrase    = "Test-3212017";
# Load the params file which will set the $paramSet variable
# !!! Set all mandatory variables used in the params file here !!!

#####
# Execution logic begins here
#####
# This needs to be done before the module is loaded as the module depends on the password being set.
$passwdCheckerModule = $PSScriptRoot+"\modules\ServicePrinciplePasswdLoader.ps1";
. $passwdCheckerModule;

Import-Module $PSScriptRoot"\modules\"ARMTemplateDeployment.psm1;
if(-not $?) { Exit -1; }

. $PARAMS_FILE_PATH;
$output      = RunAllDeployments -ParamSet $paramSet -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupLocation $LOCATION -TemplateURI $TEMPLATE_URI -ResourceGroupNamePrefix $RESOURCE_GROUP_NAME_PREFIX -Teardown $FALSE;
$deploymentFailed = $output | Select-String -Pattern "failed";
if (-not [string]::IsNullOrEmpty($deploymentFailed))
{ echo "Deployment FAILED"; }
else 
{ echo "Deployment SUCCEEDED"}

echo "====================== DEPLOYMENT OUTPUT ======================"
echo $output;
echo "==============================================================="

$teardown = Read-Host -Prompt "Teardown deployment? (Y/N)";
if ($teardown -eq "Y")
{
  echo "Tearing down first deployment";
  $resourceGroupName = $RESOURCE_GROUP_NAME_PREFIX+"0"
  TeardownDeployment -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupName $resourceGroupName;
  echo "Teardown complete";
}

Remove-Module ARMTemplateDeployment;