# Simple Windows VM with Diagnostic Settings

For Azure Stack POC TP1, enabling Monitoring for Virtual Machines from the UI is disabled. In order to test this functionality, the end user needs to deploy a Virtual Machine directly from an ARM template with Diagnostic Settings enabled. Once the VM is deployed, the Monitoring Agent that is deployed in the VM will be able to send data to the Storage Account provisioned to it.

Note: This is an advanced scenario for this technical preview release.

More Details on how to use this template will be available in the MAS Evaluation Guide.