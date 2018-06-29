# Uncomment line below only on Automated Monitoring VM.  For local machine, ServicePrinciplePasswdLoader.ps1 will dynamically set the password. 
# IMPORTANT: !!!!! Set the $global:SP_PASSWD only on the file on the monitoring VM to avoid accidental check-in with source code !!!!!
#$global:SP_PASSWD = "";

# Subscription under which resources will be deployed
$SUBSCRIPTION_ID          = "";
# Azure Location where resource group and all resources will be deployed in (format e.g. "Central US" or "centralus")
$LOCATION                 = "";
# Root folder within which all template files that are being validated are contained. Determine latest path via test
# deployment of published marketplace solution.
$MARKETPLACE_BASE_URL     = "";
$MARKETPLACE_TEMPLATE_URI = $MARKETPLACE_BASE_URL+"\mainTemplate.json";
$QUICKSTART_TEMPLATE_URI  = "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/ethereum-consortium-blockchain-network/azuredeploy.json";

$NOTIFICATION_ENABLED     = "TRUE"; # Any value other than "TRUE" will disable notification
$NOTIFICATION_USER_NAME   = "azure_bc8d0746cc32dcb3aceee23ddb70a0f7@azure.com"; # Username of sendgrid account
$NOTIFICATION_PASSWORD    = ""; # Password of sendgrid account (Stored in Key Vault of Runner subscription)
$NOTIFICATION_ALIAS       = "";