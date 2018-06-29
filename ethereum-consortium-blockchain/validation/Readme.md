# ARM Template automated validation via Powershell Guide

<Work in progress - watch this space>

## Initial setup
1. Make a copy of the ARMTemplate-automated-validation.ps1 file and include the word "personal" in the file name to avoid it from being checked-in accidentally
2. If you are testing the marketplace deployment template (mainTemplate.json) you will need to make a copy of those parameter files and swap in the location where the template files you are testing reside - replace the <SET TO BASE FOLDER LOCATION OF TEMPLTE FILE>.  e.g. you may have your files in Azure storage so place the URI of the folder where the main template is located.
3. Set the value of constants in this file to relevant ones for your environment and desired tests
4. The script will ask you to login to Azure the first time in each session.  IMPORTANT: Do not save this password into any of the scripts to avoid the risk of checking this secret into the repo accidentally
5. I recommend working in Windows PowerShell ISE as you can edit the script and see the console in onw view and it has a nice Module explorer built-in as well as auto-complete etc.

## Parameter fiels
Parameter files define a set of input parameters that are used to run multiple deployments in parallel.  If you have 5 sets of parameters, 5 deployments will be kicked off.  You can then tear down all 5 deployments with a single command (Option "T" in the script)