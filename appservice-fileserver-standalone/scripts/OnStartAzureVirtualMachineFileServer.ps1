[CmdletBinding()]
Param
(
    [string] $fileServerAdminUserName,
    [string] $fileServerAdminPassword,
    [string] $fileShareOwnerUserName,
    [string] $fileShareOwnerPassword,
    [string] $fileShareUserUserName,
    [string] $fileShareUserPassword,
    [String[]] $ZipFiles
)

function DownloadFile($uri)
{
    $retryCount = 1
    while ($retryCount -le 3)
    {
        try
        {
            Write-Verbose  "Downloading file from '$($Uri)', attempt $retryCount of 3 ..."
            $file = "$env:TEMP\$([System.IO.Path]::GetFileName((New-Object System.Uri $Uri).LocalPath))"
            Invoke-WebRequest -Uri $Uri -OutFile $file
            break
        }
        catch
        {
            if ($retryCount -eq 3)
            {
                Write-Error -Message "Error downloading file from '$($Uri)".
                throw $_
            }

            Write-Warning -Message "Failed to download file from '$($Uri)', retrying in 30 seconds ..."
            Start-Sleep -Seconds 30 
            $retryCount++
        }
    }

    Write-Verbose "Successfully downloaded file from '$($Uri)' to '$($file)'."
    return $file
}

function Expand-ZIPFile($file, $destination)
{
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) 
    {
        Expand-Archive -Path $file -DestinationPath $destination
    }
    else
    {
        # Fall back to COM to expand the zip 
        $shell = new-object -com shell.application
        $zip = $shell.NameSpace($file)
        foreach($item in $zip.items())
        {
            # 16 - Respond with "Yes to All" for any dialog box that is displayed.
            $shell.Namespace($destination).copyhere($item, 16)
        }
    }
}

function Log($out)
{
    $out = [System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss") + " ---- " + $out;
    Write-Output $out;
}

function Decode-Parameter($parameter)
{
    if ($parameter.StartsWith("base64:"))
    {
        $encodedParameter = $parameter.Split(':', 2)[1]
        $decodedArray = [System.Convert]::FromBase64String($encodedParameter);
        $parameter = [System.Text.Encoding]::UTF8.GetString($decodedArray); 
    }

    return $parameter
}

function Quote-String($str) {
	# Put single quote around the string
	# Escape single quote
    # Also escape double quote else it will be trimmed by ArgumentList
	return "'" + $str.Replace("'", "''").Replace('"', '\"') + "'"
}

try
{
    Log "Decode parameters"
    $fileServerAdminUserName = Decode-Parameter $fileServerAdminUserName
    $fileServerAdminPassword = Decode-Parameter $fileServerAdminPassword
    $fileShareOwnerUserName = Decode-Parameter $fileShareOwnerUserName
    $fileShareOwnerPassword = Decode-Parameter $fileShareOwnerPassword
    $fileShareUserUserName = Decode-Parameter $fileShareUserUserName
    $fileShareUserPassword = Decode-Parameter $fileShareUserPassword

    Log "Search and download for zip files"
    foreach ($zipFile in $ZipFiles)
    {
        # We support fetching the DSC modules ourselves...
        if ((($zipFile -as [System.Uri]).AbsoluteURI))
        {
            $zipFile = DownloadFile -Uri $zipFile
        }
        #... or having the Custom Script extension do it for us.
        else
        {
            $zipFile = "$PSScriptRoot\$zipFile"

            # Coalesce the zip file name in case the extension was omitted.
            if (-not $zipFile.EndsWith(".zip"))
            {
                $zipFile = "$zipFile.zip"
            }

            if (Test-Path $zipFile) 
            {
                Expand-ZIPFile -file $zipFile -destination "$pwd"
                Move-Item -Path $zipFile -Destination "$zipFile.expanded" -Force
            }
        }   
    }

    Log "Configure admin user"
    # Disable built-in admin if it is not our admin
    $adminGroup = Get-LocalGroup -SID 'S-1-5-32-544'
    $buildinAdmin = Get-LocalGroupMember $adminGroup | where {$_.SID.Value.EndsWith("-500")}

    if ($buildinAdmin.Name -ne "${env:COMPUTERNAME}\$fileServerAdminUserName") 
    {
        Disable-LocalUser -SID $buildinAdmin.SID
    }

    # Create or update the actual admin
    $securePassword = ConvertTo-SecureString $fileServerAdminPassword -Force -AsPlainText
    if (Get-LocalUser -Name $fileServerAdminUserName -ErrorAction SilentlyContinue) 
    {
        Set-LocalUser -Name $fileServerAdminUserName -Password $securePassword -AccountNeverExpires -PasswordNeverExpires $true
        Enable-LocalUser -Name $fileServerAdminUserName
    }
    else
    {
        New-LocalUser -Name $fileServerAdminUserName -Password $securePassword -AccountNeverExpires -PasswordNeverExpires
        Add-LocalGroupMember -Group $adminGroup -Member $fileServerAdminUserName
    }

    Log "Start App Service file server configuration."

    $cmd = ".\FileServer\single.ps1 "+
        "-fileServerAdminUserName $(Quote-String $fileServerAdminUserName) "+
        "-fileServerAdminPassword $(Quote-String $fileServerAdminPassword) "+
        "-fileShareOwnerUserName $(Quote-String $fileShareOwnerUserName) "+
        "-fileShareOwnerPassword $(Quote-String $fileShareOwnerPassword) "+
        "-fileShareUserUserName $(Quote-String $fileShareUserUserName) "+
        "-fileShareUserPassword $(Quote-String $fileShareUserPassword)"

    $process = Start-Process -FilePath Powershell.exe -ArgumentList $cmd -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0)
    {
        Log "App Service file server configuration failure. Exit code: $($process.ExitCode).";
        Write-Error "App Service file server configuration failure. Exit code: $($process.ExitCode).";

        exit -1;
    }

    Log "App Service file server configuration has completed successfully."
}
catch
{
    Log "Error: $_"

    throw;
}
