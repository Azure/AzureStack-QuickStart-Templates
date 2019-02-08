# Troubleshooting Guide for Office workloads on Azure Stack

## General DSC issues

Scenario: Deployment failed in DSC Resource

Logs: Logs are stored inside the failed VM in C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\2.76.0.0

## General Custom Script Extension Issues

Scenario: Deployment failed in Custom Script Extension

Logs: Logs are stored inside the failed VM in C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.9

## Exchange

Exchange setup logs are stored in each node in c:\ExchangeSetupLogs

## Skype

Logs: Logs are stored inside the failed VM in C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.1\Status\0.status

## SQL

Logs: Logs are stoed inside the failed VM in C:\WindowsAzure\Logs\SqlServerLogs

## Known issues

Issue: Last entry in log file customscripthandler.txt indicates sucessfull download of artifacts.
Cause: Missing or wrong file in artifact blob storage account
Resolution: Ensure additional required files that are not part of the repo are added. Review readme that outlines seperate requires downloads.