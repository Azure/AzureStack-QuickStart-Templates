param
    (
        [Parameter(Mandatory=$true)]
        [String] $WindowsFeatureName
    )


if(-not (Get-WindowsFeature -Name $WindowsFeatureName).Installed)
{
    throw "the windows feature $WindowsFeatureName is not isntalled"
}
