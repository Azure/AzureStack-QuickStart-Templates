#####
# IMPORTANT: !!!!! Ensure the password is set outside of this script to prevent a secret from being checked into the repo accidentally !!!!!
#####
# This script performs a fully automated deployment and teardown of ARM tepmplates using configured parameters and us used
# for automated canary monitoring and alerting of the Blockchain templates.  Status is e-mailed to the configured aliases
#
# Note: Instructions to setup service principle were sourced from http://blog.davidebbo.com/2014/12/azure-service-principal.html
#####
Import-Module $PSScriptRoot"\modules\"Utility.psm1;

$PRE_VALIDATION_SLEEP_SEC = 90;
$POST_CONNECTION_PRE_VALIDATION_SLEEP_SEC = 300;

# Load variables file
$variablesFilePath = $PSScriptRoot+"\multinetwork-validation-variables.ps1";
. $variablesFilePath;

# This needs to be done before the module is loaded as the module depends on the password being set.
$passwdCheckerModule = $PSScriptRoot+"\modules\ServicePrinciplePasswdLoader.ps1";
. $passwdCheckerModule;

Import-Module $PSScriptRoot"\modules\"ARMTemplateDeployment.psm1;

# uncomment for local testing
#Select-AzureRmSubscription -SubscriptionId $SUBSCRIPTION_ID

# Ensure a unique resource group name incase we don't teardown the deployment to avoid conflict with subsequent deployments
$RESOURCE_GROUP_NAME_PREFIX = "fts-automated-multi-leader-test-"+(Get-Date ([TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::UTC)) -UFormat %Y-%m-%d_%H.%M.%SZ-);

$finalOutput = "`n`n====================== BEGINNING LEADER MARKETPLACE DEPLOYMENT ======================`n`n"

try{
	$PARAMS_FILE_PATH = $PSScriptRoot+"\param-sets\mainTemplate-param-set-multinetwork.ps1";
	. $PARAMS_FILE_PATH;

	$output      = RunAllDeployments -ParamSet $paramSet -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupLocation $LOCATION -TemplateURI $LEADER_TEMPLATE_URI -ResourceGroupNamePrefix $RESOURCE_GROUP_NAME_PREFIX -Teardown $false
	$finalOutput = $finalOutput + $output;
	$deploymentFailed = $output | Select-String -Pattern "failed";
	if (-not [string]::IsNullOrEmpty($deploymentFailed))
	{ $finalOutput = $finalOutput + "One or more deployment failed so leaving failed deployments running.  PLEASE TEARDOWN AFTER INVESTIGATING."; }

	$leaderDeploymentA=$RESOURCE_GROUP_NAME_PREFIX+"0"
	$leaderDeploymentB=$RESOURCE_GROUP_NAME_PREFIX+"1"

	Start-Sleep -s $PRE_VALIDATION_SLEEP_SEC
	Validate -ResourceGroupName $leaderDeploymentA
	Validate -ResourceGroupName $leaderDeploymentB

	# read the outputs of deployment A
	$previousDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $leaderDeploymentA -deploymentName $leaderDeploymentA).Outputs
	$gatewayIdA = $previousDeploymentOutputs["gateway-Id"].Value
	$consortiumDataA = $previousDeploymentOutputs["consortium-data"].Value
	$sharedKeyA = GeneratePrefix

	# read the outputs of deployment B
	$previousDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $leaderDeploymentB -deploymentName $leaderDeploymentB).Outputs
	$gatewayIdB = $previousDeploymentOutputs["gateway-Id"].Value
	$consortiumDataB = $previousDeploymentOutputs["consortium-data"].Value
	$sharedKeyB = GeneratePrefix


	$finalOutput = $finalOutput+ "`n`n====================== BEGINNING JOINING MEMBER DEPLOYMENTS ======================`n`n"


	$PARAMS_FILE_PATH = $PSScriptRoot+"\param-sets\mainTemplate-param-set-multinetwork-join.ps1";
	. $PARAMS_FILE_PATH;

	$RESOURCE_GROUP_NAME_PREFIX = "fts-automated-multi-join-test-"+(Get-Date ([TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::UTC)) -UFormat %Y-%m-%d_%H.%M.%SZ-);
	$output      = RunAllDeployments -ParamSet $paramSet -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupLocation $LOCATION -TemplateURI $JOINING_TEMPLATE_URI -ResourceGroupNamePrefix $RESOURCE_GROUP_NAME_PREFIX -Teardown $false -RunValidation $false -JobNamePrefix "JoiningMember"
	$finalOutput = $finalOutput + $output;
	$deploymentFailed = $output | Select-String -Pattern "failed";
	if (-not [string]::IsNullOrEmpty($deploymentFailed))
	{ $finalOutput = $finalOutput + "One or more deployment failed so leaving failed deployments running.  PLEASE TEARDOWN AFTER INVESTIGATING."; }

	# read the outputs the the joining member deploy
	$joiningMemberA=$RESOURCE_GROUP_NAME_PREFIX+"0"
	$joiningMemberB=$RESOURCE_GROUP_NAME_PREFIX+"1"


	# Member Y connects to JoiningMemberA
	$previousDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $joiningMemberA -deploymentName $joiningMemberA).Outputs
	$otherGatewayIdA = $previousDeploymentOutputs["gateway-Id"].Value
	$gatewayIdY=$otherGatewayIdA
	$consortiumDataY = $previousDeploymentOutputs["consortium-data"].Value
	$sharedKeyY = GeneratePrefix

	# MemberZ connects to Leader b
	$previousDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $joiningMemberB -deploymentName $joiningMemberB).Outputs
	$otherGatewayIdB = $previousDeploymentOutputs["gateway-Id"].Value

	# run the connection script
	DownloadFile -Uri ($consortiumDataA+"/ConsortiumBridge.psm1") -Destination ".\ConsortiumBridge.psm1"
	Import-Module ".\ConsortiumBridge.psm1"

	CreateConnection $gatewayIdA $otherGatewayIdA "TestConnectionA" $sharedKeyA
	CreateConnection $gatewayIdB $otherGatewayIdB "TestConnectionB" $sharedKeyB

	Start-Sleep -s $POST_CONNECTION_PRE_VALIDATION_SLEEP_SEC
	Validate -ResourceGroupName $joiningMemberA -PeerCountGreaterThan $localPeers
	Validate -ResourceGroupName $joiningMemberB -PeerCountGreaterThan $localPeers

	<#################################
	At this point two networks are connected 
	Leader1->A
	Leader2->B

	Now we connected A->Y so the topology looks like L1->A->Y
	Connect Leader2 to Z for a hub and spoke topology;  Z<-L2->B
	#################################>
	$finalOutput = $finalOutput+ "`n`n====================== BEGINNING JOINING MEMBER DEPLOYMENTS STEP TWO ======================`n`n"


	$PARAMS_FILE_PATH = $PSScriptRoot+"\param-sets\mainTemplate-param-set-multinetwork-join-step2.ps1";
	. $PARAMS_FILE_PATH;

	$RESOURCE_GROUP_NAME_PREFIX = "fts-automated-multi-join2-test-"+(Get-Date ([TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::UTC)) -UFormat %Y-%m-%d_%H.%M.%SZ-);
	$output      = RunAllDeployments -ParamSet $paramSet -SubscriptionID $SUBSCRIPTION_ID -ResourceGroupLocation $LOCATION -TemplateURI $JOINING_TEMPLATE_URI -ResourceGroupNamePrefix $RESOURCE_GROUP_NAME_PREFIX -Teardown $false -RunValidation $false -JobNamePrefix "JoiningMember"
	$finalOutput = $finalOutput + $output;
	$deploymentFailed = $output | Select-String -Pattern "failed";
	if (-not [string]::IsNullOrEmpty($deploymentFailed))
	{ $finalOutput = $finalOutput + "One or more deployment failed so leaving failed deployments running.  PLEASE TEARDOWN AFTER INVESTIGATING."; }

	# read the outputs the the joining member deploy
	$joiningMemberY=$RESOURCE_GROUP_NAME_PREFIX+"0"
	$joiningMemberZ=$RESOURCE_GROUP_NAME_PREFIX+"1"


	$previousDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $joiningMemberY -deploymentName $joiningMemberY).Outputs
	$otherGatewayIdY = $previousDeploymentOutputs["gateway-Id"].Value
	$previousDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $joiningMemberZ -deploymentName $joiningMemberZ).Outputs
	$otherGatewayIdZ = $previousDeploymentOutputs["gateway-Id"].Value

	CreateConnection $gatewayIdY $otherGatewayIdY "TestConnectionY" $sharedKeyY
	CreateConnection $gatewayIdB $otherGatewayIdZ "TestConnectionZ" $sharedKeyB

	Start-Sleep -s $POST_CONNECTION_PRE_VALIDATION_SLEEP_SEC
	Validate -ResourceGroupName $joiningMemberY -PeerCountGreaterThan $localPeers
	Validate -ResourceGroupName $joiningMemberZ -PeerCountGreaterThan $localPeers

	$testRunFailed = $finalOutput | Select-String -Pattern "failed";
}
catch
{
	$finalOutput = $finalOutput + "`n`n!!!!!!!!!!!!!!!!!!!!DEPLOYMENT FAILED!!!!!!!!!!!!!!!!!!!!`n`n"
	$finalOutput = $finalOutput + $error[0]
	$finalOutput = $finalOutput + "`n"
	$testRunFailed = $TRUE
}


# if tests passed then tear it all down
if($testRunFailed -eq $TRUE)
{
	$finalOutput = $finalOutput+"`n`n====================Preventing Teardown====================`n`n"
}
else
{
    if( $leaderDeploymentA -ne $NULL){ 	       
		$finalOutput = $finalOutput+(TeardownDeployment $SUBSCRIPTION_ID $leaderDeploymentA)
		}

    if( $leaderDeploymentB -ne $NULL){ 
		$finalOutput = $finalOutput+(TeardownDeployment $SUBSCRIPTION_ID $leaderDeploymentB)
		}

    if( $joiningMemberA -ne $NULL){ 
		$finalOutput = $finalOutput+(TeardownDeployment $SUBSCRIPTION_ID $joiningMemberA)
		}

    if( $joiningMemberB -ne $NULL){ 
		$finalOutput = $finalOutput+(TeardownDeployment $SUBSCRIPTION_ID $joiningMemberB)
		}

    if( $joiningMemberY -ne $NULL){ 
		$finalOutput = $finalOutput+(TeardownDeployment $SUBSCRIPTION_ID $joiningMemberY)
		}

    if( $joiningMemberZ -ne $NULL){
		$finalOutput = $finalOutput+(TeardownDeployment $SUBSCRIPTION_ID $joiningMemberZ)
		}
}

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
  { $Subject = "MultiNetwork:  One or more deployments FAILED"; }
  else { $Subject = "MultiNetwork:  All deployments SUCCEEDED"; }

  $Body = "$finalOutput";

  Send-MailMessage -smtpServer $SMTPServer -Credential $credential -Usessl -Port 587 -from $EmailFrom -to $EmailTo -subject $Subject -Body $Body;
}