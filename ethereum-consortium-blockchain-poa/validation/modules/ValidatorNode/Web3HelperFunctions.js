const fs = require('fs');
const Web3 = require('web3');
const EthereumTx = require('ethereumjs-tx')

// Load the arguments
var rpcAddress = process.argv[1];
var rpcPort = process.argv[2];

//var rpcAddress = "127.0.0.1";
//var rpcPort = 8545;

// Setup some of the constants
const validatorContractAddress = '0x0000000000000000000000000000000000000006';
const validatorContractAbi = JSON.parse('[{"constant":false,"inputs":[{"name":"proposedAdminAddress","type":"address"},{"name":"alias","type":"string"}],"name":"proposeAdmin","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"validatorAddresses","type":"address[]"}],"name":"removeValidators","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getProposedCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getAdmins","outputs":[{"name":"","type":"address[200]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"admin","type":"address"}],"name":"voteAgainst","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"alias","type":"string"}],"name":"updateAdminAlias","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"validatorAddresses","type":"address[]"}],"name":"addValidators","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"finalizeChange","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getAdminCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"admin","type":"address"}],"name":"getAliasForAdmin","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getValidators","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getValidatorCapacity","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"proposedAdminAddress","type":"address"}],"name":"voteFor","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getProposedAdmins","outputs":[{"name":"","type":"address[200]"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"name":"admin","type":"address"}],"name":"AdminProposed","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"admin","type":"address"}],"name":"AdminAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"admin","type":"address"}],"name":"AdminRemoved","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"caller","type":"address"}],"name":"FinalizeCalled","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"caller","type":"address"}],"name":"AddValidatorCalled","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_parent_hash","type":"bytes32"},{"indexed":false,"name":"_new_set","type":"address[]"}],"name":"InitiateChange","type":"event"}]');


// Helper Functions
function CreateWeb3Reference() { return new Web3(new Web3.providers.HttpProvider(`http://${rpcAddress}:${rpcPort}`)); }
function CreateValidatorContract(web3) {
    return web3.eth.contract(validatorContractAbi).at(validatorContractAddress);
}

var web3 = CreateWeb3Reference();
var validatorContract = CreateValidatorContract(web3);

function sendMethodTransaction(fromAccountAddress, methodData, privateKey) {
    var nonceToUse = getTransactionCount(fromAccountAddress);
    const txParams = {
        nonce: nonceToUse,
        gasPrice: 0,
        gasLimit: 20000000,// Todo, estimate gas
        from: fromAccountAddress,
        to: validatorContractAddress,
        value: '0x00',
        data: methodData,
        chainId: 10101010
    }
    const tx = new EthereumTx(txParams)
    const privateKeyBuffer = Buffer.from(privateKey, 'hex');
    tx.sign(privateKeyBuffer)
    const serializedTx = tx.serialize()

    web3.eth.sendRawTransaction('0x' + serializedTx.toString('hex'), function (err, hash) {
        if (!err)
            console.log(hash);
        else
            console.log(err);
    });
}


// Validator Functions
function getAdmins() {
    validatorContract.getAdmins(function (error, result) {
        if (!error) {
            var adminsList = [];
            result.forEach(eachElement => {
                if (eachElement == "0x0000000000000000000000000000000000000000") { }
                else { adminsList.push(eachElement); }
            });
            console.log(JSON.stringify(adminsList));
        }
        else {
            console.error(error);
        }
    });
}

function getProposedAdmins() {
    validatorContract.getProposedAdmins(function (error, result) {
        if (!error) {
            var adminsList = [];
            result.forEach(eachElement => {
                if (eachElement == "0x0000000000000000000000000000000000000000") { }
                else { adminsList.push(eachElement); }
            });
            console.log(JSON.stringify(adminsList));
        }
        else {
            console.error(error);
        }
    });
}

function getValidators() {
    validatorContract.getValidators(function (error, result) {
        if (!error) {
            var adminsList = [];
            result.forEach(eachElement => {
                if (eachElement == "0x0000000000000000000000000000000000000000") { }
                else { adminsList.push(eachElement); }
            });
            console.log(JSON.stringify(adminsList));
        }
        else {
            console.error(error);
        }
    });
}

function getAliasForAdmin(accountAddress) {
    validatorContract.getAliasForAdmin(accountAddress, function (error, result) {
        if (!error)
            console.log(result);
        else
            console.error(error);
    });
}

function getValidatorCapacity() {
    validatorContract.getValidatorCapacity(function (error, result) {
        if (!error)
            console.log(result.toString());
        else
            console.error(error);
    });
}

function addValidators(fromAccountAddress, privateKey, addresses) {
    var methodData = validatorContract.addValidators.getData(addresses);
    sendMethodTransaction(fromAccountAddress, methodData, privateKey);
}

function addValidatorData(validatorAddress) {
    console.log(validatorContract.addValidators.getData([validatorAddress]));
}

function removeValidatorData(validatorAddress) {
    console.log(validatorContract.removeValidators.getData([validatorAddress]));
}

function voteAgainstData(adminAddress) {
    console.log(validatorContract.voteAgainst.getData(adminAddress));
}

function getProposedCount() {
    validatorContract.getProposedCount(function (error, result) {
        if (!error)
            console.log(result.toString());
        else
            console.error(error);
    });
}

function updateAdminAlias(fromAccountAddress, alias, privateKey) {
    var methodData = validatorContract.updateAdminAlias.getData(alias);
    sendMethodTransaction(fromAccountAddress, methodData, privateKey);
}

function proposeAdmin(fromAccountAddress, proposeAddress, alias, privateKey) {
    var methodData = validatorContract.proposeAdmin.getData(proposeAddress, alias);
    sendMethodTransaction(fromAccountAddress, methodData, privateKey);
}

function voteFor(fromAccountAddress, voteAddress, privateKey) {
    var methodData = validatorContract.voteFor.getData(voteAddress);
    sendMethodTransaction(fromAccountAddress, methodData, privateKey);
}

function voteAgainst(fromAccountAddress, voteAddress, privateKey) {
    var methodData = validatorContract.voteAgainst.getData(voteAddress);
    sendMethodTransaction(fromAccountAddress, methodData, privateKey);
}


// Standard Ethereum Functions
function getAccountBalance(accountAddress) {
    console.log(web3.eth.getBalance(accountAddress).toString());
}

function getTransactionCount(accountAddress) {
    var web3 = CreateWeb3Reference();
    return web3.eth.getTransactionCount(accountAddress)
}

function getTransaction(transactionHash) {
    console.log(JSON.stringify(web3.eth.getTransaction(transactionHash)));
}

function fromWei(amount, unit){ 
    console.log(web3.fromWei(amount, unit))
}

function toWei(amount, unit){
    console.log(web3.tomWei(amount, unit))
}

// Export the functions so they can be used by powershell scripts
module.exports = {
    getTransaction,
    getValidators,
    getAdmins,
    getProposedAdmins,
    getAccountBalance,
    getAliasForAdmin,
    getValidatorCapacity,
    getProposedCount,
    proposeAdmin,
    updateAdminAlias,
    voteFor,
    voteAgainst,
    addValidatorData,
    removeValidatorData,
    voteAgainstData,
    fromWei,
    toWei
};