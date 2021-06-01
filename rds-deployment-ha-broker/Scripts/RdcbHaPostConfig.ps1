<#
.SYNOPSIS
HA Broker configuration.

.DESCRIPTION
Script should run on the new RD Connection Broker in the deployment.

.PARAMETER newBroker
Name of the new server to add as secondary broker.

#>

param 
    ( 
     [String]$existingBroker,
     [String]$primaryDbConnectionString,
     [string]$domainName,
     [String]$username,
     [String]$password,
     [string]$clientAccessName,
     [string]$sqlClientUrl,
     [string]$dnsServer,
     [string]$sqlServer
    ) 

$localhost = [System.Net.Dns]::GetHostByName((hostname)).HostName
$domainNetbios = (Get-ADDomain -Current LocalComputer).NetBIOSName
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($domainNetbios + "\" + $username,(ConvertTo-SecureString -String $password -AsPlainText -Force))

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
        }
    )
} # End of Config Data

$Logfile = ".\CB_PostConfig1.1_{0}.log" -f (get-date -Format "yyyyMMddhhmmss")

function GetServersByRole($roleName)
{
    $RemoteSqlOdbcconn = new-object System.Data.Odbc.OdbcConnection	
    $RemoteSqlOdbcconn.ConnectionString = $primaryDbConnectionString
    $RemoteSqlOdbcconn.Open()
    
    $OdbcCmdStr = "SELECT s.Name FROM rds.Server s INNER JOIN rds." + $roleName + " cb ON s.Id = cb.ServerId"
    $RemoteSqlOdbccmd = new-object System.Data.Odbc.OdbcCommand
    $RemoteSqlOdbccmd.CommandText = $OdbcCmdStr
    $RemoteSqlOdbccmd.Connection = $RemoteSqlOdbcconn
    $SqlRdr = $RemoteSqlOdbccmd.ExecuteReader()    
    while ($SqlRdr.Read() -eq $true)
    {
        $ServerArr += @($SqlRdr.GetString(0).Split('.')[0])
    }
    
    $SqlRdr.Close()
    $RemoteSqlOdbccmd.Dispose()
    $RemoteSqlOdbcconn.Close()
    return $ServerArr
}

function GetIpAddress([string]$compName, [int]$ipType)
{
    $IPconfigset = Get-WmiObject -ComputerName $compName Win32_NetworkAdapterConfiguration    
    foreach ($IPConfig in $IPconfigset) 
    {  
        if (!$Ipconfig.IPaddress -or 
            ($Ipconfig.IPEnabled -eq $FALSE)) 
        {
           continue; 
        }
        	
        foreach ($addrStr in $Ipconfig.Ipaddress) 
        {
            $addr = [System.Net.IPAddress]::Parse($addrStr);
            if (($ipType -eq 4) -and 
                ($addr.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork))
            {                
                return $addr;
            }
            elseif (($ipType -eq 6) -and 
                    ($addr.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) -and
                    (!$addrStr.StartsWith("fe80")))
            {                
                return $addr;
            }
        }
    }  
}

function AddDomainComputersToRDSMgmtServerGroup()
{
    $rdmsGroupName = "RDS Management Servers";
    $objOU = [ADSI]("WinNT://" + $env:computername)
    $objGroup = $objOU.psbase.children.find($rdmsGroupName)
    
    $machineAcc = "Domain Computers"
    $membershipExists = $objGroup.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name",'GetProperty',$null,$_,$null)} | where {$_ -eq $machineAcc}
    if ( !($membershipExists.length -gt 1) ) 
    {
        $objGroup.Add("WinNT://" + $domainName + "/" + $machineAcc)
    }   
}

function SetupVMHA($compName)
{
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $compName);

    $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\VMHostAgent\Parameters', 'ReadWriteSubTree', 'SetValue');
    $regKey.SetValue('tssdis',$brokerMachineList, 'string');
	
    AddDomainComputersToRDSMgmtServerGroup;
}

function SetupRDSH($compName)
{
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $compName);

    $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings', 'ReadWriteSubTree', 'SetValue');
    $regKey.SetValue('SessionDirectoryLocation',$brokerMachineList, 'string');

    AddDomainComputersToRDSMgmtServerGroup;
}

function SetupRDWA($compName)
{
    $rdweb = Get-WmiObject -ComputerName $compName AppSettingssection -namespace root\webadministration -Authentication 6
    $appSection = $rdweb[0]
    $objAppSettings = $appSection.AppSettings

    foreach ($cfg in $objAppSettings)
    {
        if ($cfg.key.CompareTo("radcmserver") -eq 0)
        {
            Write-Host "Changing" $cfg.Value "to" $brokerMachineList
            $cfg.Value = $brokerMachineList
        }
    }
    $appSection.SetPropertyValue("AppSettings", $objAppSettings)
    $PutOptions = New-Object System.Management.PutOptions
    $PutOptions.Type = 1  # update only
    $appSection.Put($PutOptions)
    Write-Host "Successfully configured RDWeb's Broker name"
}

function SetupGroups($sqlServer, $computerName, $domain)
{
$computerName = $computerName.ToLower() -replace "." + $domain.ToLower()

Invoke-Command -ComputerName $sqlServer -ScriptBlock {
param( $computerName )
  $grMembers = net localgroup "RDS Management Servers"
  $fnd = $false
  foreach ($gr in $grMembers)
  {
    if ( $gr -Like "*$computerName$" ) { $fnd = $true; break }
  }
  if ( $fnd -eq $false ) 
  {
     Write-Output ("Adding $($computerName) to the local RDS Management Servers group")
     net localgroup "RDS Management Servers" /add "$computerName`$"
  }
  else
  {
     Write-Output("Computer $($computerName) is already a member of the group")
  } 
} -ArgumentList $computerName
}

function SetupCB($compName, $clientURL)
{
	Write-Output("Starting Install of client on broker machine: $compName [end]")
        Write-Output("Active broker: $activeBroker")
        Write-Output("Client URL: $clientURL")
	try
	{
		Invoke-Command -ComputerName $compName -ScriptBlock { param($clientURL, $installPath, $domainNetbios)
                        Write-Output("Running Invoke Command")
			$installPath = "$env:temp\Install-$(Get-Date -format 'yyyy-dd hh-mm-ss').msi"

			if(!(Split-Path -parent $installPath) -or !(Test-Path -PathType Container (Split-Path -parent $installPath))) {
			   $installPath = Join-Path $pwd (Split-Path -leaf $path)
			}

			Write-Output("Downloading new client from: $($installPath)")
			Invoke-WebRequest -Uri $clientURL -OutFile $installPath -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer
			Write-Output("FinishedDownloading Client and starting install")
            sleep -Seconds 10
			$result = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i ""$installPath"" /passive ADDLOCAL=ALL APPGUID={0CC618CE-F36A-415E-84B4-FB1BFF6967E1} IACCEPTSQLNCLILICENSETERMS=YES" -Wait -PassThru).ExitCode
			Write-Output("Result from installing client: $($result)")

			#
			# Add Domain Computers to RDS Endpoint Servers group
                        Write-Output("Checking Domain computer registration")
			$rdsServersGroupName = "RDS Endpoint Servers"
			$objOU = [ADSI]("WinNT://" + $env:computername)
			$objGroup = $objOU.psbase.children.find($rdsServersGroupName)
			$machineAcc = "Domain Computers"
                        Write-Output("Checking Membership")

			$membershipExists = $objGroup.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name",'GetProperty',$null,$_,$null)} | where {$_ -eq $machineAcc}
			if ( !($membershipExists.length -gt 1) ) 
			{
                                Write-Output("Attempting to add domain: $domainNetbios and Account: $machineAcc")
				$objGroup.Add("WinNT://" + $domainNetbios + "/" + $machineAcc)
                                Write-Output("Account added")
			}    
                        Write-Output("Completed setup for broker")
		} -ArgumentList $clientURL, $installPath, $domainNetbios | Out-File -Append $Logfile
	} 
	catch [Exception] {
    WriteLog("Exception installing the client on the localhost: $($_.Exception.Message)")
    throw
 } 
 Write-Output "Setting up Group membership for $compName on SQL"
 if(![string]::IsNullOrEmpty($sqlServer)) # only run if $sqlServer is not null
 {
	SetupGroups $sqlServer $compName $domainNetbios
 }
}

Function WriteLog
{
 Param ([string]$logstring)

 Add-content $Logfile -value $logstring
 Write-Host $logstring
}

WriteLog("Starting PostConfig on machine $($localhost)")
if ($existingBroker.ToLower().EndsWith($domainName) -eq $false)
{
  $existingBroker = $existingBroker + "." + $domainName
}

if ($clientAccessName.ToLower().EndsWith($domainName) -eq $false)
{
  $clientAccessName = $clientAccessName + "." + $domainName
}

#Impersonate user
$ImpersonatedUser = @{}
WriteLog "impersonating as '$username'..."
Add-Type -Namespace Import -Name Win32 -MemberDefinition @'
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool LogonUser(string user, string domain, string password, int logonType, int logonProvider, out IntPtr token);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr handle);
'@

$tokenHandle = 0
$returnValue = [Import.Win32]::LogonUser($userName, $domainName, $password, 2, 0, [ref]$tokenHandle)

if (!$returnValue)
{
    $errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error();
    WriteLog "failed a call to LogonUser with error code: $errCode"
    throw [System.ComponentModel.Win32Exception]$errCode
}
else
{
    $ImpersonatedUser.ImpersonationContext = [System.Security.Principal.WindowsIdentity]::Impersonate($tokenHandle)
    [void][Import.Win32]::CloseHandle($tokenHandle)
    WriteLog "impersonating user $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) returnValue: '$returnValue'"
}

whoami

SetupCB $localhost $sqlClientUrl
SetupCB $existingBroker $sqlClientUrl

$cb1IP = (Resolve-DnsName -Name $existingBroker -Type A).IPAddress
$cb2IP = (Resolve-DnsName -Name $localhost -Type A).IPAddress

Write-Output("Creating DNS Records")
Invoke-Command -ComputerName $dnsServer  -ScriptBlock {
        param($domainName, $cb1IP, $cb2IP, $clientAccessName)
        $zone = "$domainName"
        $name = $clientAccessName.Split('.') | select -First 1
        $res= Get-DnsServerResourceRecord -ZoneName $zone -Name $name -EA SilentlyContinue
        if ( $res -ne $null ) { 
          Remove-DnsServerResourceRecord -ZoneName $zone -Name $name -RRType "A" -force
        }
        $cmd = "Add-DnsServerResourceRecordA -ZoneName $zone -Name $name -AllowUpdateAny -Ipv4Address ""$cb1IP"",""$cb2IP"" -PassThru -TimeToLive 00:00:30"
        Write-Output($cmd)
        $rec = Invoke-Expression $cmd
        if ($rec -eq $null) 
	    {
		  throw "Unable to add Dns record for ip address $($cb1IP) and $($cb2IP)"
	    }
	    Write-Output("Successfully added ip address")
	} -ArgumentList $domainName, $cb1IP, $cb2IP, $clientAccessName  | Out-File -Append $Logfile
    
Write-Output("Completed writing DNS Records")

WriteLog("Getting Connection Broker High Availability settings")
$res = Get-RDConnectionBrokerHighAvailability -ConnectionBroker $existingBroker
WriteLog("Result from Get-RDConnectionBrokerHighAvailability: $($res)")

if ($null -eq $res )
{
    WriteLog("existingBroker: $($existingBroker)")
    WriteLog("primaryDbConnectionString: $($primaryDbConnectionString)")
    WriteLog("clientAccessName: $($clientAccessNames)")
    Set-RDConnectionBrokerHighAvailability -ConnectionBroker $existingBroker -DatabaseConnectionString $primaryDbConnectionString -ClientAccessName $clientAccessName
	WriteLog("Returning from Set-RDConnectionBroker, checking high availability")
    $res = Get-RDConnectionBrokerHighAvailability -ConnectionBroker $existingBroker
    if ( $null -eq $res )
    {
       WriteLog "Unable to set the connection broker as high availability"
    }
	WriteLog("Result from Get-RDConnectionBrokerHighAvailability: $($res)")
}

WriteLog("Getting Connection broker to see if $($localhost) is added as a connection broker")
$res = get-rdserver -ConnectionBroker $existingBroker -Role RDS-CONNECTION-BROKER | select Server
if ( $res.Server.ToLower().StartsWith($localhost.ToLower()) )
{
   WriteLog( "$($localhost) is already added as a server")
}
else
{
	WriteLog("Add-RdServer -Server $($localhost) -Role RDS-CONNECTION-BROKER")
	Add-RdServer -ConnectionBroker $existingBroker -Server $localhost -Role RDS-CONNECTION-BROKER
}

$brokerMachines = GetServersByRole "RoleRdcb"
$rdwaMachines = GetServersByRole "RoleRdwa"
$rdshMachines = GetServersByRole "RoleRdsh"
$rdvhMachines = GetServersByRole "RoleRdvh"

$brokerCount = 1;
$brokerMachineList = "";
foreach ($broker in $brokerMachines)
{
    $brokerMachineList = $brokerMachineList + $broker + "." + $env:USERDNSDOMAIN;
    if ($brokerCount -lt $brokerMachines.Count)
    {
        $brokerMachineList = $brokerMachineList + ";"
    }
    $brokerCount++;
}

foreach ($broker in $brokerMachines)
{
    #Write-Host "Setting up Redirector machine : " + $broker
    #SetupRDSH $broker;
}

foreach ($rdvh in $rdvhMachines)
{
    #Write-Host "Setting up RDVH machine : " + $rdvh
    #SetupVMHA $rdvh;
}

foreach ($rdsh in $rdshMachines)
{
    #Write-Host "Setting up RDSH machine : " + $rdsh
    #SetupRDSH $rdsh;
}

foreach ($rdwa in $rdwaMachines)
{
    #Write-Host "Setting up RDWA machine : " + $rdwa
    #SetupRDWA $rdwa
}

Writelog "remove impersonation..."
$ImpersonatedUser.ImpersonationContext.Undo()

WriteLog("Completed setup")

