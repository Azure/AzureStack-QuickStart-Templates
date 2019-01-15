# Error code messages

| File	        | Code           | Message  |
| ------------------- |--------------|------|
|	configure-poa.sh	|	1	|	Insufficient parameters supplied |
|		                |	2	|	Invalid deployment mode |
|		                |	3	|	Failed to setup rc.local for restart on VM reboot
|		                |	4	|	Failed to install a new key from packages.microsoft.com server
|		                |	5	|	Failed to $2 after $NOOFTRIES number of attempts | 
|		                |	6	|	Failed to authenticate with azure key vault | 
|		                |	7	|	Failed to download docker image $image
|		                |	8	|	Unable to run docker image $image
|		                |	9	|	Unable to orchestrate poa |	

||||
|	orchestrate-poa.bash	|	21	|	Insufficient parameters supplied |
|		                |	22	|	Unable to generate account address from recovery phrase |
|		                |	23	|	Unable to set a secret for passphrase in azure key vault |
|		                |	24	|	Generated address list should not be empty or null |
|		                |	25	|	Failed to start parity node in dev mode. |
 

||||
|	configure-validator.sh	|	30	|	Unable to login to azure container registry	|
|		                |	31	|	Failed to download docker image $image|
|		                |	32	|	Unable to run docker image $ETHADMIN_DOCKER_IMAGE |
|		                |	33	|	Failed to start container from image $ETHSTAT_DOCKER_IMAGE |
|		                |	34	|	Unable to get boot nodes from leader network |
|		                |	35	|	Insufficient parameters supplied    |
|		                |	36	|	Unable to start validator node. The expected number of lease records and config files were not found in blob container  

||||
|	run-validator.sh	|	40	|	Unable to start validator node. Passphrase url should not be empty	|
|		                |	41	|	Unable to start validator node. Passphrase should not be empty |
|		                |	42	|	Unable to run docker image $VALIDATOR_DOCKER_IMAGE |
|		                |	43	|	Insufficient parameters supplied    |

||||
|	validator.sh	    |	45	|	Parity is not configured properly. The enode url is not valid	|
|		                |	46	|	Failed to add bootnode to parity |
|		                |	47	|	Unable to generate validator address from passphrase   |
|		                |	48	|	Unable to generate validator address from passphrase   |
|		                |	49	|	Insufficient parameters supplied


||||
|	poa-utility.sh	    |	51	|	Failed to authenticate with azure key vault |
|		                |	52	|	Unable to download file $file after $numAttempt number of attempts. |
|		                |	53	|	Failed to $2 after $numAttempt number of attempts.


||||
|	orchestrate-util.bash	|	60	|	Unable to generate prefund passphrase |
|		                |	61	|	Unable to generate prefund account address |
|		                |	62	|	Unable to upload prefund passphrase file to azure storage blob after $NOTRIES attempts |
|		                |	63	|	Contract bytecode should not be empty or null |
|		                |	64	|	Unable to upload $BLOB_NAME file to azure storage blob after $uploadAttempts attempts |
|		                |	65	|	Unable to upload passphrase URI file - $uriFile - to azure storage blob after $uploadAttempts attempts |
|		                |	66	|	Unable to upload address list file to azure storage blob after $uploadAttempts attempts |
|		                |	67	|	Unable to download file $file after $numAttempt number of attempts |
|		                |	68	|	Unable to get data from url $url after $numAttempt number of attempts |

# OMS Parity Logging
Parity logs are read into OMS at path /var/log/parity/parity.log
