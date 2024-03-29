# Uncomment line below only on Automated Monitoring VM.  For local machine, ServicePrinciplePasswdLoader.ps1 will dynamically set the password. 
# IMPORTANT: !!!!! Set the $global:SP_PASSWD only on the file on the monitoring VM to avoid accidental check-in with source code !!!!!
#$global:SP_PASSWD = "";


# Subscription under which resources will be deployed
$SUBSCRIPTION_ID            = ""; # "Azure Blockchain Service Runners" subscription
# Azure Location where resource group and all resources will be deployed in (format e.g. "Central US" or "centralus")
$LOCATION                 = "";
# Root folder within which all template files that are being validated are contained. Determine latest path via test
# deployment of published marketplace solution.
$BASE_URL="https://gallery.azure.com/artifact/20161101/microsoft-azure-blockchain.azure-multi-member-blockchain-service-previewethereum-consortium-leader.1.0.1/Artifacts"
$LEADER_TEMPLATE_URI = $BASE_URL+"/mainTemplate.json";
$JOINING_TEMPLATE_URI = "https://gallery.azure.com/artifact/20161101/microsoft-azure-blockchain.azure-multi-member-blockchain-service-previewethereum-consortium-member.1.0.5/Artifacts/mainTemplate.json";

$NOTIFICATION_ENABLED     = "FALSE"; # Any value other than "TRUE" will disable notification
$NOTIFICATION_USER_NAME   = ""; # Username of sendgrid account
$NOTIFICATION_PASSWORD    = ""; # Password of sendgrid account
$NOTIFICATION_ALIAS       = "";

$authType      = "password";
$vmAdminPasswd = "";
$ethPasswd     = $vmAdminPasswd;
$passphrase    = $vmAdminPasswd;
$sshPublicKey  = ""
