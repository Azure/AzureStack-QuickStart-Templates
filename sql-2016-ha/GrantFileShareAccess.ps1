#
# Copyright="© Microsoft Corporation. All rights reserved."
#

param(
        [Parameter(Mandatory)]
        [String] $DomainName,
        
        [Parameter(Mandatory)]
        [String] $LocalShareName,

        [Parameter(Mandatory)]
        [String] $AccessAccountName
)

$accountNameFull = "$DomainName\$AccessAccountName"

Write-Verbose -Message "Getting account names"
$accounts = @((Get-FileShareAccessControlEntry -Name $LocalShareName -ErrorAction SilentlyContinue).AccountName)

Write-Verbose -Message "Account names with access: $accounts"

if(-not ($accounts -contains $accountNameFull))
{
    Write-Verbose -Message "Granting access to: $accountNameFull"
    Grant-FileShareAccess -Name $LocalShareName  -AccountName $accountNameFull -AccessRight Full
}



                    
                        
