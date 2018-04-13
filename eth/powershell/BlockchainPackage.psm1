<#
.SYNOPSIS
    Packages up template topology for deployment
.PARAMETER MarketplaceDirectory
    The marketplace directory path
.PARAMETER Topology
    Topology name
.PARAMETER OutputFile
    Path to the output zip file
#>
function CreatePackage(
	[string] $MarketplaceDirectory,
	[string] $Topology,
	[string] $OutputFile
){
	Remove-Item "temp" -Recurse
	md temp
	md temp\ethereum
	md temp\nested
	md temp\etheradmin
	md temp\powershell

	# don't force the $OutputFile parameter to be passed in, if it's not it just the same name as the Topology folder + .zip appended
	if( !([bool]$OutputFile))
	{
		$OutputFile=$Topology+".zip"
	}

	$root = Join-Path "." "temp"
	$ethereumPath = Join-Path $root "ethereum"
	$templatePath = Join-Path $MarketplaceDirectory $Topology
	$mainTemplate = Join-Path $templatePath "mainTemplate.json"
	$createUiDef = Join-Path $templatePath "createUiDefinition.json"
	$commonDir = Join-Path $MarketplaceDirectory "..\common"	
	$genesisTemplate = "genesis-template.json"
	$scriptsFolder = Join-Path $commonDir "scripts"
	$nestedFolder = Join-Path $commonDir "nested"
	$adminFolder = Join-Path $scriptsFolder "etheradmin"
	$powershellFolder = Join-Path $commonDir "powershell"

	# copy the files to the appropriate directory structure
	Copy-Item $mainTemplate $root
	Copy-Item $createUiDef $root
	Copy-Item (Join-Path $commonDir $genesisTemplate) (Join-Path $root "ethereum")
	Copy-Item (Join-Path $scriptsFolder "*") (Join-Path $root "scripts")
	Copy-Item (Join-Path $nestedFolder "*") (Join-Path $root "nested")
	Copy-Item (Join-Path $adminFolder "*") (Join-Path $root "etheradmin")
	Copy-Item (Join-Path $powershellFolder "*") (Join-Path $root "powershell")

	# zip it
	$root = Join-Path $root "*"
	Compress-Archive -Path $root -Force -DestinationPath $OutputFile
}