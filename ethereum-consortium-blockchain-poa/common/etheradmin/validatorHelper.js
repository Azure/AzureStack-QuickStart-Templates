var Web3 = require('web3');
const EthereumTx = require('ethereumjs-tx')


module.exports = function (web3LocalRpc, web3IPC) {
    var module = {};

    const validatorContractAddress = '0x0000000000000000000000000000000000000006';
    const validatorContractAbi = JSON.parse('[{"constant":false,"inputs":[{"name":"proposedAdminAddress","type":"address"},{"name":"alias","type":"string"}],"name":"proposeAdmin","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"validatorAddresses","type":"address[]"}],"name":"removeValidators","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getProposedCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getAdmins","outputs":[{"name":"","type":"address[200]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"admin","type":"address"}],"name":"voteAgainst","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"alias","type":"string"}],"name":"updateAdminAlias","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"validatorAddresses","type":"address[]"}],"name":"addValidators","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"finalizeChange","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getAdminCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"adminAddress","type":"address"}],"name":"getAdminValidators","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"admin","type":"address"}],"name":"getAliasForAdmin","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getValidators","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getValidatorCapacity","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"proposedAdminAddress","type":"address"}],"name":"voteFor","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getProposedAdmins","outputs":[{"name":"","type":"address[200]"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"name":"admin","type":"address"}],"name":"AdminProposed","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"admin","type":"address"}],"name":"AdminAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"admin","type":"address"}],"name":"AdminRemoved","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"caller","type":"address"}],"name":"FinalizeCalled","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"caller","type":"address"}],"name":"AddValidatorCalled","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_parent_hash","type":"bytes32"},{"indexed":false,"name":"_new_set","type":"address[]"}],"name":"InitiateChange","type":"event"}]');

    function CreateValidatorContract(web3) {
        console.log("test");
        return web3.eth.contract(validatorContractAbi).at(validatorContractAddress);
    }

    var validatorContract = CreateValidatorContract(web3IPC);
    var validatorContractRpc = CreateValidatorContract(web3LocalRpc)

    //getValidatorCapacity
    module.GetValidatorCapacity = function () {
        return validatorContractRpc.getValidatorCapacity();
    }

    module.AddValidator = function (fromAccountAddress, validatorAddress, privateKey) {
        var methodData = validatorContract.addValidators.getData([validatorAddress]);
        sendMethodTransaction(fromAccountAddress, methodData, privateKey, web3IPC);
    }

    module.RemoveValidator = function (fromAccountAddress, validatorAddress, privateKey) {
        var methodData = validatorContract.removeValidators.getData([validatorAddress]);
        sendMethodTransaction(fromAccountAddress, methodData, privateKey, web3IPC);
    }

    module.voteAgainst = function (fromAccountAddress, voteAddress, privateKey) {
        var methodData = validatorContract.voteAgainst.getData(voteAddress);
        sendMethodTransaction(fromAccountAddress, methodData, privateKey, web3IPC);
    }

    module.proposeAdmin = function (fromAccountAddress, proposeAddress, alias, privateKey) {
        var methodData = validatorContract.proposeAdmin.getData(proposeAddress, alias);
        sendMethodTransaction(fromAccountAddress, methodData, privateKey, web3IPC);
    }

    module.GetAdmins = function () {
        var adminResult = validatorContractRpc.getAdmins();
        var adminsList = [];
        adminResult.forEach(eachElement => {
            if (eachElement == "0x0000000000000000000000000000000000000000") {} else {
                adminsList.push(eachElement);
            }
        });
        return adminsList;
    }

    module.GetAdminsAndValidators = function () {
        var adminsList = [];

        module.GetAdmins().forEach(eachElement => {
            var newAdmin = new AdminAndValidator(eachElement);
            newAdmin.Validators = validatorContractRpc.getAdminValidators(eachElement);
            adminsList.push(newAdmin);
        });
        return adminsList;
    }

    function AdminAndValidator(n) {
        this.AdminAccount = n;
        this.Validators = [];
    }


    function sendMethodTransaction(fromAccountAddress, methodData, privateKey, web3) {
        web3.eth.getTransactionCount(fromAccountAddress, 'pending', function (err, nonceToUse) {
            const txParams = {
                nonce: nonceToUse,
                gasPrice: 0,
                gasLimit: 20000000, // Todo, estimate gas
                from: fromAccountAddress,
                to: validatorContractAddress,
                value: '0x00',
                data: methodData,
                chainId: 10101010
            }
            const tx = new EthereumTx(txParams)
            const privateKeyBuffer = new Buffer(privateKey, 'hex');
            tx.sign(privateKeyBuffer)
            const serializedTx = tx.serialize()

            web3.eth.sendRawTransaction('0x' + serializedTx.toString('hex'), function (err, hash) {
                if (!err)
                    console.log(hash);
                else
                    console.log(err);
            });
        });
    }

    console.log("Finished Loading validatorHelper.js");

    return module;
};