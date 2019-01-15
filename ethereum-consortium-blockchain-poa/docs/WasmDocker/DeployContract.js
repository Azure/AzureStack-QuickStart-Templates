// Will create a new account using the password you provide, deploy the contract, and then output the Account #, Contract Address, and the ABI of the contract

var Web3 = require("web3");
var fs = require("fs");
var net = require('net');

/*
 * Parameters
 */
var newAccountPassword = process.argv[2];

/*
 * Start Deployment
 */

// Connect to the IPC api endpoint of the local parity client
var web3 = new Web3('/opt/parity/jsonrpc.ipc', net);

// Read in the contract ABI
var abi = JSON.parse(fs.readFileSync("./target/json/TokenInterface.json"));
// Read in the contract bytecode
var codeHex = '0x' + fs.readFileSync("./target/pwasm_tutorial_contract.wasm").toString('hex');

// Create a new account to deploy the contract
web3.eth.personal.newAccount(newAccountPassword)
    .then((newAccount) => {
        console.log(`New account#: ${newAccount}`);

        // Create the Contract
        var TokenContract = new web3.eth.Contract(abi, {
            data: codeHex,
            from: newAccount
        });

        // Create the deployment transaction
        var TokenDeployTransaction = TokenContract.deploy({
            data: codeHex,
            arguments: [10000000]
        });

        // Unlock the new account
        web3.eth.personal.unlockAccount(newAccount, newAccountPassword)        
            .then(() => TokenDeployTransaction.estimateGas())
            // Send the transaction
            .then(gas => TokenDeployTransaction.send({
                gasLimit: gas,
                from: newAccount
            }))
            // Print out the results
            .then(contract => {
                console.log(`Address of new contract: ${contract.options.address}`);
                console.log("Contract abi:");
                console.log(JSON.stringify(abi, null, 0));
                process.exit();
            }).catch(err => console.log(err));
    });