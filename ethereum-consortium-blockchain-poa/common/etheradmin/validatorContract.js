class ValidatorContract {

    constructor(web3provider, contractAbi, isLoaded) {
        this.web3 = new Web3(web3provider);;

        // Todo: Read ABI from Azure Blob or other dynamic source.
        this.validatorContractAbi = JSON.parse(contractAbi);
        this.validatorContractAddress = '0x0000000000000000000000000000000000000006';

        this.contract = this.web3.eth.contract(this.validatorContractAbi).at(this.validatorContractAddress);
        var options = {
            fromBlock: "latest",
            address: this.validatorContractAddress
          };
        var filter = web3.eth.filter(options);

        filter.watch(function (error, log) {
            if (isLoaded()) {
                location.reload();
            }
        });
    }

    get ValidatorContractEthereum() {
        return this.contract;
    }

    GetValidatorCapacityAsync(fn) {
        try {
            this.ValidatorContractEthereum.getValidatorCapacity(
                (error, result) => {
                    if (!error) {
                        console.log("ValidatorContract.GetValidatorCapacityAsync() returning: " + result);
                        fn(result);
                    } else
                        console.error(error);
                }
            );
        } catch (error) {
            console.log("Error in ValidatorContract.GetValidatorCapacityAsync(): " + error);
        }
    }

    GetAdminsAsync(fn) {
        this.ValidatorContractEthereum.getAdmins((error, result) => {
            if (!error) {
                var adminsList = [];
                result.forEach(eachElement => {
                    if (eachElement == "0x0000000000000000000000000000000000000000") {} else {
                        adminsList.push(eachElement);
                    }
                });
                console.log("ValidatorContract.GetAdminsAsync() returning: " + adminsList);
                fn(adminsList)
            } else {
                console.log("Error in ValidatorContract.GetAdminsAsync(): " + error);
            }
        });
    }

    GetProposedAdminsAsync(fn) {
        this.ValidatorContractEthereum.getProposedAdmins((error, result) => {
            if (!error) {
                var adminsList = [];
                result.forEach(eachElement => {
                    if (eachElement == "0x0000000000000000000000000000000000000000") {} else {
                        adminsList.push(eachElement);
                    }
                });
                console.log("ValidatorContract.GetProposedAdminsAsync() returning: " + adminsList);
                fn(adminsList)
            } else {
                console.log("Error in ValidatorContract.GetProposedAdminsAsync(): " + error);
            }
        });
    }

    GetValidatorsForAdmin(adminAccount, fn) {
        try {
            this.ValidatorContractEthereum.getAdminValidators(adminAccount,
                (error, result) => {
                    if (!error) {
                        console.log(`ValidatorContract.GetValidatorsForAdmin(${adminAccount}) returning: ${result}`);
                        fn(result);
                    } else
                        console.error(error);
                }
            );
        } catch (error) {
            console.log(`Error in ValidatorContract.GetValidatorsForAdmin(${adminAccount}): ${error}`);
        }
    }

    GetValidators(fn){
        try {
            this.ValidatorContractEthereum.getValidators((error, result) => {
                    if (!error) {
                        console.log(`ValidatorContract.getValidators() returning: ${result}`);
                        fn(result);
                    } else
                        console.error(error);
                }
            );
        } catch (error) {
            console.log(`Error in ValidatorContract.GetValidators(): ${error}`);
        }
    }

    GetAliasForAdmin(account, fn) {
        try {
            this.ValidatorContractEthereum.getAliasForAdmin(account,
                (error, result) => {
                    if (!error) {
                        console.log(`ValidatorContract.GetAliasForAdmin(${account}) returning: ${result}`);
                        fn(result);
                    } else
                        console.error(error);
                }
            );
        } catch (error) {
            console.log(`Error in ValidatorContract.GetAliasForAdmin(${account}): ${error}`);
        }
    }

    UpdateAliasAsync(adminAlias, fn) {
        var methodData = this.ValidatorContractEthereum.updateAdminAlias.getData(adminAlias);
        this.web3.eth.sendTransaction({
            to: this.validatorContractAddress,
            gasPrice: 0,
            data: methodData
        }, function (error, transactionHash) {
            if (!error) {
                // Todo: display output to user and add watch to notify when block has been mined.
                console.log(`UpdateAliasAsync() Transaction Hash: ${transactionHash}`);
                fn(transactionHash);
            } else {
                console.log(`Error in ValidatorContract.UpdateAliasAsync(${adminAlias}): ${error}`);
                fn("", error);
            }
        });
    }

    ProposeAdminAsync(adminAccount, adminAlias, fn) {
        var methodData = this.ValidatorContractEthereum.proposeAdmin.getData(adminAccount, adminAlias);
        this.web3.eth.sendTransaction({
            to: this.validatorContractAddress,
            gasPrice: 0,
            data: methodData
        }, function (error, transactionHash) {
            if (!error) {
                // Todo: display output to user and add watch to notify when block has been mined.
                console.log(`ProposeAdminAsync() Transaction Hash: ${transactionHash}`);
                fn(transactionHash);
            } else {
                console.log(`Error in ValidatorContract.ProposeAdminAsync(${adminAccount}, ${adminAlias}): ${error}`);
                fn("", error);
            }
        });
    }

    VoteAgainstAdminAsync(adminAccount, fn) {
        var methodData = this.ValidatorContractEthereum.voteAgainst.getData(adminAccount);
        this.web3.eth.sendTransaction({
            to: this.validatorContractAddress,
            gasPrice: 0,
            data: methodData
        }, function (error, transactionHash) {
            if (!error) {
                // Todo: display output to user and add watch to notify when block has been mined.
                console.log(`VoteAgainstAdminAsync() Transaction Hash: ${transactionHash}`);
                fn(transactionHash);
            } else {
                console.log(`Error in ValidatorContract.VoteAgainstAdminAsync(${adminAccount}): ${error}`);
                fn("", error);
            }
        });
    }

    VoteForProposedAdminAsync(adminAccount, fn) {
        var methodData = this.ValidatorContractEthereum.voteFor.getData(adminAccount);
        this.web3.eth.sendTransaction({
            to: this.validatorContractAddress,
            gasPrice: 0,
            data: methodData
        }, function (error, transactionHash) {
            if (!error) {
                // Todo: display output to user and add watch to notify when block has been mined.
                console.log(`VoteForProposedAdminAsync() Transaction Hash: ${transactionHash}`);
                fn(transactionHash);
            } else {
                console.log(`Error in ValidatorContract.VoteForProposedAdminAsync(${adminAccount}): ${error}`);
                fn("", error);
            }
        });
    }

    AddValidator(validatorAccount, fn) {
        var methodData = this.ValidatorContractEthereum.addValidators.getData([validatorAccount]);
        this.web3.eth.sendTransaction({
            to: this.validatorContractAddress,
            gasPrice: 0,
            data: methodData
        }, function (error, transactionHash) {
            if (!error) {
                // Todo: display output to user and add watch to notify when block has been mined.
                console.log(`AddValidator() Transaction Hash: ${transactionHash}`);
                fn(transactionHash);
            } else {
                console.log(`Error in AddValidator.RemoveValidator(${validatorAccount}): ${error}`);
                fn("", error);
            }
        });
    }

    RemoveValidator(validatorAccount, fn) {
        var methodData = this.ValidatorContractEthereum.removeValidators.getData([validatorAccount]);
        this.web3.eth.sendTransaction({
            to: this.validatorContractAddress,
            gasPrice: 0,
            data: methodData
        }, function (error, transactionHash) {
            if (!error) {
                // Todo: display output to user and add watch to notify when block has been mined.
                console.log(`RemoveValidator() Transaction Hash: ${transactionHash}`);
                fn(transactionHash);
            } else {
                console.log(`Error in ValidatorContract.RemoveValidator(${validatorAccount}): ${error}`);
                fn("", error);
            }
        });
    }
}