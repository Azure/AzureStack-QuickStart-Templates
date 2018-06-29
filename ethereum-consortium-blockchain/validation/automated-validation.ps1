#####
# IMPORTANT: !!!!! Ensure the password is set outside of this script to prevent a secret from being checked into the repo accidentally !!!!!
#####
# This script performs a fully automated deployment and teardown of ARM tepmplates using configured parameters and us used
# for automated canary monitoring and alerting of the Blockchain templates.  Status is e-mailed to the configured aliases
#
# Note: Instructions to setup service principle were sourced from http://blog.davidebbo.com/2014/12/azure-service-principal.html
#####

# Load variables file
$variablesFilePath = $PSScriptRoot+"\automated-validation-variables.ps1";
. $variablesFilePath;

# Load template params file
$templateParamsFilePath = $PSScriptRoot+"\automated-validation-template-params.ps1";
. $templateParamsFilePath;

# This needs to be done before the module is loaded as the module depends on the password being set.
$passwdCheckerModule = $PSScriptRoot+"\modules\ServicePrinciplePasswdLoader.ps1";
. $passwdCheckerModule;

Import-Module $PSScriptRoot"\modules\"ARMTemplateDeployment.psm1;

# Ensure a unique resource group name incase we don't teardown the deployment to avoid conflict with subsequent deployments
$RESOURCE_GROUP_NAME_PREFIX = "automated-canary-test-"+(Get-Date ([TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::UTC)) -UFormat %Y-%m-%d_%H.%M.%SZ-);

$finalOutput = "`n`n====================== BEGINNING MARKETPLACE DEPLOYMENT ======================`n`n"

$PARAMS_FILE_PATH = $PSScriptRoot+"\param-sets\mainTemplate-param-set-canary.ps1";
. $PARAMS_FILE_PATH;
$output      = RunAllDeployments -ParamSet $paramSet -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupLocation $LOCATION -TemplateURI $MARKETPLACE_TEMPLATE_URI -ResourceGroupNamePrefix $RESOURCE_GROUP_NAME_PREFIX;
$finalOutput = $finalOutput + $output;
$deploymentFailed = $output | Select-String -Pattern "failed";
if (-not [string]::IsNullOrEmpty($deploymentFailed))
{ $finalOutput = $finalOutput + "One or more deployment failed so leaving failed deployments running.  PLEASE TEARDOWN AFTER INVESTIGATING."; }

$finalOutput = $finalOutput + "`n`n====================== BEGINNING QUICKSTART DEPLOYMENT ======================`n`n";

$PARAMS_FILE_PATH = $PSScriptRoot+"\param-sets\azureDeploy-param-set-canary.ps1";
. $PARAMS_FILE_PATH;
$RESOURCE_GROUP_NAME_PREFIX = "automated-canary-test-"+(Get-Date ([TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::UTC)) -UFormat %Y-%m-%d_%H.%M.%SZ-);

$output      = RunAllDeployments -ParamSet $paramSet -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupLocation $LOCATION -TemplateURI $QUICKSTART_TEMPLATE_URI -ResourceGroupNamePrefix $RESOURCE_GROUP_NAME_PREFIX;
$finalOutput = $finalOutput + $output;
$deploymentFailed = $output | Select-String -Pattern "failed";
if (-not [string]::IsNullOrEmpty($deploymentFailed))
{ $finalOutput = $finalOutput + "One or more deployment failed so leaving failed deployments running.  PLEASE TEARDOWN AFTER INVESTIGATING."; }

$testRunFailed = $finalOutput | Select-String -Pattern "failed";
Remove-Module ARMTemplateDeployment;

if(-not [string]::IsNullOrEmpty($NOTIFICATION_ENABLED) -and $NOTIFICATION_ENABLED -eq "TRUE")
{ 
  # Sendgrid Email Service Info
  $Password = ConvertTo-SecureString $NOTIFICATION_PASSWORD -AsPlainText -Force;
  $credential = New-Object System.Management.Automation.PSCredential $NOTIFICATION_USER_NAME, $Password;
  $SMTPServer = "smtp.sendgrid.net";
  $EmailFrom = "templatemonitoring@tmonitoring.com";
  $EmailTo = @($NOTIFICATION_ALIAS);
  $Subject = "";

  if (![string]::IsNullOrEmpty($testRunFailed))
  { $Subject = "One or more deployments FAILED"; }
  else { $Subject = "All deployments SUCCEEDED"; }

  $Body = "$finalOutput";

  Send-MailMessage -smtpServer $SMTPServer -Credential $credential -Usessl -Port 587 -from $EmailFrom -to $EmailTo -subject $Subject -Body $Body;
}