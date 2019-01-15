<#
.SYNOPSIS
    Packages up template topology for deployment
.PARAMETER OutputFile
    Path to the output zip file
#>

Param(
	[string] $OutputFile
)

md temp

$OutputFile=$OutputFile+".zip"

$temp = Join-Path "." "temp"
$commonPath = Join-Path ".." "common\*"
$createUiDef = Join-Path "..\marketplace" "createUiDefinition.json"

# copy the files to the appropriate directory structure
Copy-Item -Path $commonPath -Recurse -Destination $temp -Container
Copy-Item $createUiDef $temp

# zip it, zip it real good
$temp = Join-Path $temp "*"
Compress-Archive -Path $temp -Force -DestinationPath (Join-Path ".." $OutputFile)

Remove-Item "temp" -Recurse