# Deploy Custom Script VM Extension to existing Windows VM (with PowerShell command)

This template deploys the Custom Script VM Extension to an existing Windows VM in an Azure Stack environment. It takes a parameter for vmName, and allows for the execution of a PowerShell command (as seen in the commandToExecute Extension setting).

Example PS Command (Sets DNS within the VM): powershell -ExecutionPolicy Unrestricted Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses 192.168.100.2, 8.8.8.8
