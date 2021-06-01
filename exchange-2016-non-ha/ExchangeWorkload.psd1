#
# Copyright="© Microsoft Corporation. All rights reserved."
#

@{
	AllNodes = @(
		@{
			NodeName = "localhost";
			PSDscAllowDomainUser = $true;
			RebootNodeIfNeeded = $true;
			ActionAfterReboot = "ContinueConfiguration";
		}
	);
}
