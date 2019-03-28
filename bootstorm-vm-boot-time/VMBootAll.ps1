#
# Copyright="?Microsoft Corporation. All rights reserved."
#

Configuration ConfigureVMBootAll
{
    param (
        [Parameter(Mandatory)]
        [PSCredential]$AzureAccountCreds,
        [Parameter(Mandatory)]
        [string]$TenantId,
        [Parameter(Mandatory)]
        [string]$Location,
        [Parameter(Mandatory)]
        [string]$VMName,
        [Parameter(Mandatory)]
        [int32]$VMCount,
        [Parameter(Mandatory)]
        [PSCredential]$VMAdminCreds,
        [Parameter(Mandatory)]
        [string]$AzureStorageAccount,
        [Parameter(Mandatory)]
        [string]$AzureStorageAccessKey,
        [Parameter(Mandatory)]
        [string]$AzureStorageEndpoint,
        [Parameter(Mandatory)]
        [string]$AzureSubscription
    )

    # Turn off private firewall
    netsh advfirewall set privateprofile state off
    # Get full path and name of the script being run
    $PSPath = $PSCommandPath

    # Local file storage location
    $localPath = "$env:SystemDrive"

    # Log file
    $logFileName = "VMBootDSC.log"
    $logFilePath = "$localPath\$logFileName"

    $AzureAccountUsername = $AzureAccountCreds.UserName
    $AzureAccountPasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AzureAccountCreds.Password)
    $AzureAccountPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($AzureAccountPasswordBSTR)

    $VMAdminUserName = $VMAdminCreds.UserName
    $VMAdminPasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VMAdminCreds.Password)
    $VMAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($VMAdminPasswordBSTR)

    # DSC Script Resource - VM Bootstorm
    Script VMBAll
    {
        TestScript = { (Get-ScheduledTask -TaskName "VMBootAll" -ErrorAction SilentlyContinue) -ne $null }

        GetScript = { return @{"TaskName" = "VMBootAll"} }

        SetScript = {
            function IsAzureStack
            {
                param
                (
                    [Parameter(Mandatory)]
                    $Location
                )
                if($Location -eq "AzureCloud" -or $Location -eq "AzureChinaCloud" -or $Location -eq "AzureUSGovernment"  -or $Location -eq "AzureGermanCloud") {
                    return $false
                }
                return $true

            }

            # Azure uses AzureAdApplicationId and AzureAdApplicationPassword values as AzureUserName and AzurePassword parameters respectively
            # AzureStack uses tenant UserName and Password values as AzureUserName and AzurePassword parameters respectively
            $azureUsername = $using:AzureAccountUsername
            $azurePassword = $using:AzureAccountPassword
            $tenant = $using:TenantId
            $location = $using:Location
            $vmName = $using:VMName
            $vmCount = $using:VMCount
            # Scheduled task execution credentials without any logged-in user
            $vmAdminUserName = $using:VMAdminUserName
            $vmAdminPassword = $using:VMAdminPassword
            $storageAccount = $using:AzureStorageAccount
            $storageKey = $using:AzureStorageAccessKey
            $storageEndpoint = $using:AzureStorageEndpoint
            $subscription = $using:AzureSubscription

            $storageEndpoint = $storageEndpoint.ToLower()
            # Prepare storage context to upload results to Azure storage table
            if($storageEndpoint.Contains("blob")) {
                $storageEndpoint = $storageEndpoint.Substring($storageEndpoint.LastIndexOf("blob") + "blob".Length + 1)
                $storageEndpoint = $storageEndpoint.replace("/", "")
                # Remove port number from storage endpoint e.g. http://saiostorm.blob.azurestack.local:3456/
                if($storageEndpoint.Contains(":")) {
                    $storageEndpoint = $storageEndpoint.Substring(0, $storageEndpoint.LastIndexOf(":"))
                }
            }

            "Storage endpoint given: $using:AzureStorageEndpoint Storage endpoint passed to script: $storageEndpoint" | Tee-Object -FilePath $logFilePath -Append

            # Disable windows update
            sc.exe config wuauserv start=disabled
            sc.exe stop wuauserv

            # Enable task scheduler event logs
            $taskSchedulerlogName = 'Microsoft-Windows-TaskScheduler/Operational'
            $taskLog = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $taskSchedulerlogName
            $taskLog.IsEnabled=$true
            $taskLog.SaveChanges()

            $psPath = $using:PSPath
            $psScriptDir = Split-Path -Parent -Path $psPath
            $psScriptName = "VMBootAllScript.ps1"
            $psScriptPath = "$psScriptDir\$psScriptName"
            $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "& $psScriptPath -azureUserName $azureUsername -azurePassword $azurePassword -tenant $tenant -location $location -vmName $vmName -vmCount $vmCount -azureStorageAccount $storageAccount -azureStorageAccessKey $storageKey -azureStorageEndpoint $storageEndpoint -AzureSubscription $subscription -Verbose" -ErrorAction Ignore
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -ErrorAction Ignore
            $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 2) -ErrorAction Ignore
            Unregister-ScheduledTask -TaskName "VMBootAll" -Confirm:0 -ErrorAction Ignore
            Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -TaskName "VMBootAll" -Description "VMBootstorm" -User $vmAdminUserName -Password $vmAdminPassword -RunLevel Highest -ErrorAction Ignore


            ######################
            ### AZURE RM SETUP ###
            ######################
            $logFilePath = $using:logFilePath
            $azureStackSdkPath = $using:azureStackSdkPath
            $azureStackInstallerPath = $using:azureStackInstallerPath

            if((IsAzureStack -Location $location) -eq $true) {
                # Ignore server certificate errors to avoid https://api.azurestack.local/ certificate error
                add-type @"
                using System.Net;
                using System.Security.Cryptography.X509Certificates;
                public class TrustAllCertsPolicy : ICertificatePolicy {
                    public bool CheckValidationResult(
                        ServicePoint srvPoint, X509Certificate certificate,
                        WebRequest request, int certificateProblem) {
                        return true;
                    }
                }
"@
                [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
                Write-Warning -Message "CertificatePolicy set to ignore all server certificate errors"

                $count = 0
                $installFinished = $false
                while (!$installFinished -and $count -lt 5) {
                    try {
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                        Set-PSRepository -InstallationPolicy Trusted -Name PSGallery                    
                        Install-Module -Name AzureRM -RequiredVersion 1.2.10 -Scope AllUsers -ErrorAction Stop -Confirm:0
                        $installFinished = $true
                    }
                    catch {
                        $count++
                        Start-Sleep -Seconds 10
                        Write-Warning "Could not install AzureRM module.  Trying again ($count / 5)"
                    }
                }

                # Import Azure Resource Manager PS module if already present
                try {
                    "Importing Azure module" | Tee-Object -FilePath $logFilePath -Append
                    Import-Module AzureRm -ErrorAction Stop | Out-Null
                } catch [Exception] {
                    "Cannot import AzureRm module. Cannot proceed further without AzureRm module. Exception: $_" | Tee-Object -FilePath $logFilePath -Append
                }
            }
            # Azure Cloud
            else {
                # Import Azure Resource Manager PS module if already present
                try {
                    "Importing Azure module" | Tee-Object -FilePath $logFilePath -Append
                    Import-Module AzureRm -ErrorAction Stop | Out-Null
                }
                # Install Azure Resource Manager PS module
                catch {
                    # Suppress prompts
                    $ConfirmPreference = 'None'
                    "Cannot import Azure module, proceeding with installation" | Tee-Object -FilePath $logFilePath -Append

                    # Install AzureRM
                    try {
                        Get-PackageProvider -Name nuget -ForceBootstrap -Force | Out-Null
                        Install-Module AzureRm -repository PSGallery -Force -Confirm:0 -Scope AllUsers | Out-Null
                    }
                    catch {
                        "Installation of AzureRm module failed." | Tee-Object -FilePath $logFilePath -Append
                    }

                    # Import AzureRM
                    try {
                        Import-Module AzureRm -ErrorAction Stop | Out-Null
                    } catch {
                        "Cannot import Azure module. Try importing after restart PowerShell instance. Cannot proceed further without Azure module." | Tee-Object -FilePath $logFilePath -Append
                    }
                }
            }
            Disable-AzureRmDataCollection

            # Test status file
            $statusFilePath = "$localPath\VMBootStatus.log"

            # Wait for VM bootstorm test to finish if vm count is small and DSC can finish within 90 minutes
            $waitCount = 75
            while(((Test-Path $statusFilePath) -eq $false) -and ($waitCount -gt 0)) {
                "Waiting for bootstorm test to finish $waitCount" | Tee-Object -FilePath $logFilePath -Append
                Start-Sleep -Seconds 60
                $waitCount--
            }

            if((Test-Path $statusFilePath) -eq $false) {
                "Bootstorm test finished successfully." | Tee-Object -FilePath $logFilePath -Append
            }
            else {
                "Bootstorm test not finished successfully." | Tee-Object -FilePath $logFilePath -Append
            }
        }
    }
}

