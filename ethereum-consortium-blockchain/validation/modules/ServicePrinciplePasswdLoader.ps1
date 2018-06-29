##
# This module should be dot sourced.  It checks if the service principle password was already loaded from
# key vault and loads if if not.  Vault access is restricted to authorized users.
# Logging in as a service principle avoids asking the user to login (with 2FA) from within each job session
# where the parent's context is not available
##

if([string]::IsNullOrEmpty($global:SP_PASSWD)) {
  echo "Service Principle password is not set.  Attempting to set it."
  Try {
    # Test to see if user is logged in.  Select-AzureRmSubscription with error if there is no active login.
    if ((Select-AzureRmSubscription -SubscriptionName "Blockchain NonProd").Account.AccountType -ne "User")
    {
      echo "Found a non-user logged in.  Logging in as current user.";
      Login-AzureRmAccount; 
    }
  } Catch {
    echo "No login found.  Logging in as current user.";
    # Login as current user
    Login-AzureRmAccount;
  } Finally {
    # Store the service principle password from the vault so we can login as the service principle in job sessions
    $global:SP_PASSWD =  (Get-AzureKeyVaultSecret -VaultName BlockchainTeamSecrets -Name blockchain-service-principle-dev).SecretValueText;
    echo "Service Principle password retrieved and set.";
  }
}