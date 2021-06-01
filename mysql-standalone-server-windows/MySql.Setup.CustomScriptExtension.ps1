# Copyright (c) Microsoft Corporation. All rights reserved.
# {FileName} {Version} {DateTime}
# {BuildRepo} {BuildBranch} {BuildType}-{BuildArchitecture}

#requires -Version 4.0

<#
.SYNOPSIS
   Installs MySQL Servers for the Microsoft.MySql resource provider agent.
.DESCRIPTION
   Installs MySQL Servers by downloading .zip packages and extracting to c:\MySql directory.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true, HelpMessage="MySql Admin User Name")]
    [ValidateNotNull()]
    [string]$MySqlAdminUserName,

    [Parameter(Mandatory=$true, HelpMessage="MySql Admin User Password")]
    [ValidateNotNull()]
    [string]$MySqlAdminPassword,

    [Parameter(Mandatory=$true, HelpMessage="MySql Version")]
    [ValidateNotNull()]
    [string]$MySqlVersion,

    
    [Parameter(Mandatory=$true, HelpMessage="MySql Port")]
    [ValidateNotNull()]
    [string]$MySqlPort,

    [Parameter(Mandatory=$true, HelpMessage="MySql Installation Package Uri")]
    [ValidateNotNull()]
    [string]$MySqlInstallationPackageUri
)

function Download-Package([string] $FileUri)
{
    $fileName = Split-Path $FileUri -Leaf
    $destinationFileName = (Join-Path "$PSScriptRoot" $fileName)
    if( -not (Test-Path $destinationFileName))
    {
        Write-Verbose -Verbose "Download of $fileName started"
        $downloadJob = Start-BitsTransfer -Source $FileUri -Description "Download $fileName" -DisplayName "Download $fileName" -Destination $destinationFileName -Asynchronous -RetryInterval 60 -Priority Foreground
        $startTime = [System.Datetime]::Now
        while (-not ((Get-BitsTransfer -JobId $downloadJob.JobId).JobState -eq "Transferred"))
        {
            Start-Sleep -Seconds (30)
            Write-Verbose -Verbose -Message ("Waiting for download:  $fileName, time taken: {0}" -f ([System.DateTimeOffset]::Now - $startTime).ToString())
            Write-Verbose -Message ($downloadJob | Format-List | Out-String)
        }
        Complete-BitsTransfer -BitsJob $downloadJob
        Write-Verbose -Message "Download: $fileName completed." -Verbose
    }
    else
    {
        Write-Verbose -Verbose "$fileName already exists at $destinationFileName, download of $fileName skipped"
    }
}

function Expand-ZipFile([string]$zipPathName)
{
    $zipPathName = (Resolve-Path -Path $zipPathName).Path
    $path = Split-Path -Path $zipPathName -Parent
    Write-Verbose -Message "Source: $zipPathName"
    Write-Verbose -Message "Target: $path"

    # NOTE: Using Shell.Application opens UI which breaks silent scripted install.
    #$shellApp = New-Object -ComObject Shell.Application
    #$zipFile = $shellApp.NameSpace($zipPathName)
    #$target = $shellApp.NameSpace($path)
    #$target.Copyhere($zipFile.Items())

    $assembly = [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPathName, $path)
}

function Expand-ZipFileTo([string]$zipPathName, [string]$path = $null)
{
    $zipPathName = (Resolve-Path -Path $zipPathName).Path
    if (-not $path)
    {
        $path = Split-Path -Path $zipPathName -Parent
    }
    $zipFileTitle = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Path $zipPathName -Leaf))

    Write-Verbose -Message "Source: $zipPathName"
    Write-Verbose -Message "Target: $path"
    $shellApp = New-Object -ComObject Shell.Application
    $zipFile = $shellApp.NameSpace("$zipPathName\$zipFileTitle")
    $target = $shellApp.NameSpace($path)
    $target.Copyhere($zipFile.Items())
}

function Copy-Folder([string]$source, [string]$destination)
{
    # Use Robocopy to report progress of folder copy.
    $source = $source.TrimEnd('\')
    $destination = $destination.TrimEnd('\')
    Write-Verbose -Message "Robocopy.exe '$source' '$destination' /MIR" -Verbose
    & Robocopy.exe "$source" "$destination" /MIR /NFL /NDL /NP
}

function Install-MySqlServer
{
    param
    (

        [Parameter(Mandatory=$true, HelpMessage="MySql Admin User Credential")]
        [ValidateNotNull()]
        [PSCredential]$MySqlAdminCredential,

        [Parameter(Mandatory=$true, HelpMessage="MySql Installation Package Uri")]
        [ValidateNotNull()]
        [string]$MySqlInstallationPackageUri,

        [Parameter(Mandatory=$true, HelpMessage="MySql Version")]
        [ValidateNotNull()]
        [string]$MySqlVersion,

    
        [Parameter(Mandatory=$true, HelpMessage="MySql Port")]
        [ValidateNotNull()]
        [string]$MySqlPort
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        Write-Verbose -Message "BEGIN $($MyInvocation.MyCommand.Name)" -Verbose
        
        Download-Package -FileUri $MySqlInstallationPackageUri
        $fileName = Split-Path $MySqlInstallationPackageUri -Leaf
        $zipPathName = (Join-Path "$PSScriptRoot" $fileName)
        

        # NOTE: Copy from inside ZIP file to destination is too slow.
        #Expand-ZipFileTo -zipPathName $zipPathName -path $package.Destination

        # Extract all files in place, then copy to destination is faster.
        $expandPath = $zipPathName.Substring(0, $zipPathName.LastIndexOf(".zip")) # Trim .zip extension
        
        if (Test-Path -Path $expandPath -PathType Container)
        {
            Remove-Item -Path $expandPath -Force -Recurse | Out-Null
        }

        New-Item -Path $expandPath -ItemType Directory -Force | Out-Null
        Expand-ZipFile -zipPathName $zipPathName
        $Destination = Join-Path $env:SystemDrive "MySql"
        $Destination = Join-Path $Destination $fileName.Substring(0, $fileName.LastIndexOf(".zip"))

        if (-not (Test-Path -Path $Destination -PathType Container))
        {
            New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        }
        Copy-Folder -source $expandPath -destination $Destination

        Write-Verbose -Message "$($MyInvocation.MyCommand.Name) Packages installed (Elapsed: $($stopwatch.Elapsed))"

        $serviceName = "MySqlServcie${MySqlVersion}".Replace(".","")
        $defaultCnfPath = Join-Path $env:SystemDrive "my.cnf"
        $defaultCreateUser = Join-Path $PSScriptRoot "createuser.txt"
        $defaultCnfContent = "[{0}]{3}port={1}{3}basedir={2}{3}" -f $serviceName, $MySqlPort, $Destination, [Environment]::NewLine

        $installExePath = Join-Path $Destination "bin\mysqld.exe"
        $mysqlExePath = Join-Path $Destination "bin\mysql.exe"
        
        if (-not (Test-Path $installExePath))
        {
            Write-Error "Cound not find the mysql installation file $installExePath "
        }

        if( -not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue))
        {
            if($MySqlVersion -eq "5.6" -or $MySqlVersion -eq "5.5" -or $MySqlVersion -eq "5.7")
            {
               if ($MySqlVersion -eq "5.7")
               {
                    # Initialize the data folder
                    if(-not (Test-Path (Join-Path $Destination "data")))
                    {
                        & $installExePath --initialize-insecure
                    }
                }
                # install mysql servcie
                Set-Content -Path $defaultCnfPath -Value $defaultCnfContent -Force
                & $installExePath --install $serviceName
            
                # Start MySql service
                Start-Service -Name $serviceName
            }
            else
            {
                throw ("Do not support to install MySql version: {0} " -f $MySqlVersion)
            }

            #Create user
            $createUserContent = "CREATE USER '{0}'@'%' IDENTIFIED BY '{1}';GRANT ALL ON *.* TO '{0}'@'%' WITH GRANT OPTION;" -f $MySqlAdminCredential.UserName, $MySqlAdminCredential.GetNetworkCredential().password
            Set-Content -Path $defaultCreateUser -Value $createUserContent -Force
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $mysqlExePath  -u root -P $MySqlPort < $defaultCreateUser" -Wait

        }
        else
        {
            Write-Verbose -Message "$serviceName service is already installed"
        }


        New-NetFirewallRule -Action Allow -DisplayName “Allow MySql Port $MySqlPort” -Description “Allow MySql port $MySqlPort” -Direction Inbound -Protocol TCP -LocalPort $MySqlPort
    }
    catch
    {
        Write-Error -Message $_.ToString() -Verbose
    }
    finally
    {
        
        if(Test-Path -Path $defaultCreateUser)
        {
            Remove-Item -Path $defaultCreateUser -Force
        }
        if(Test-Path -Path $defaultCnfPath)
        {
            Remove-Item -Path $defaultCnfPath -Force
        }
        $stopwatch.Stop()
        Write-Verbose -Message "END $($MyInvocation.MyCommand.Name) (Elapsed: $($stopwatch.Elapsed))" -Verbose
    }
}



#-------------------------------------------------------------------------------
# Main
$ErrorActionPreference = "Stop"

try
{
    $timestamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
    $logPath = (New-Item -Path "$env:SystemDrive\Logs" -ItemType Directory -Force).FullName
    $logFile = Join-Path -Path $logPath -ChildPath "$($MyInvocation.MyCommand.Name)_${timestamp}.txt"
    Start-Transcript -Path $logFile -Force
    $MySqlAdminCredential= New-Object System.Management.Automation.PSCredential($MySqlAdminUserName, (ConvertTo-SecureString -String $MySqlAdminPassword -AsPlainText -Force)) 
    Install-MySqlServer -MySqlInstallationPackageUri $MySqlInstallationPackageUri -MySqlAdminCredential $MySqlAdminCredential -MySqlVersion $MySqlVersion -MySqlPort $MySqlPort
}
catch
{
    Write-Error $_
    exit -1 # Error
}
finally
{
    try
    {
        Stop-Transcript
        [string]::Join("`r`n", (Get-Content -Path $logFile)) | Out-File $logFile
    }
    catch
    {
        Write-Warning -Message $_.Exception.Message
    }
}
