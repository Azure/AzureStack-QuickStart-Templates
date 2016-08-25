## Configure the environment with the Add-AzureRmEnvironment cmdlt
$endptOut = Invoke-RestMethod "$("https://api.$env:USERDNSDOMAIN".ToLowerInvariant())/metadata/endpoints?api-version=1.0"
$envName = "AzureStackCloud"
Add-AzureRmEnvironment -Name ($envName) `
				-ActiveDirectoryEndpoint ($ActiveDirectoryEndpoint = $($endptOut.authentication.loginEndpoint) + "5454420b-2e38-4b9e-8b56-1712d321cf33" + "/") `
				-ActiveDirectoryServiceEndpointResourceId ($ActiveDirectoryServiceEndpointResourceId = $($endptOut.authentication.audiences[0])) `
				-ResourceManagerEndpoint ($ResourceManagerEndpoint = $("https://api.$env:USERDNSDOMAIN".ToLowerInvariant())) `
				-GalleryEndpoint ($GalleryEndpoint = $endptOut.galleryEndpoint) `
				-GraphEndpoint ($GraphEndpoint = $endptOut.graphEndpoint) `
			   -StorageEndpointSuffix ($StorageEndpointSuffix="$($env:USERDNSDOMAIN)".ToLowerInvariant()) `
			   -AzureKeyVaultDnsSuffix ($AzureKeyVaultDnsSuffix="vault.$($env:USERDNSDOMAIN)".ToLowerInvariant())

## Authenticate a user to the environment (you will be prompted during authentication)
    $privateEnv = Get-AzureRmEnvironment $envName
    $privateAzure = Add-AzureRmAccount -Environment $privateEnv -Verbose
    Select-AzureRmProfile -Profile $privateAzure

## Select an existing subscription where the deployment will take place
    Get-AzureRmSubscription -SubscriptionName "SUBSCRIPTION_NAME"  | Select-AzureRmSubscription

# Set Deployment Variables
$myNum = "001" #Modify this per deployment
$RGName = "myRG$myNum"
$myLocation = "local"

$templateFile= "azuredeploy.json"
$templateParameterFile= "azuredeploy.parameters.json"
# For SSHKeys use below parameters.json.Fix the GEN-* values before proceeding to next steps
#$templateParameterFile= "azuredeploy-sshkeys.parameters.json"

# Create Resource Group for Template Deployment
New-AzureRmResourceGroup -Name $RGName -Location $myLocation

# Deploy Template 
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $RGName `
    -TemplateFile $templateFile `
	-TemplateParameterFile $templateParameterFile
```
