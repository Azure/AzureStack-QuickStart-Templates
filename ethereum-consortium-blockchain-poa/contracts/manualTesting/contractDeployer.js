const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');

// Connect to local Ethereum node
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8540"));

// Load contract into memory and compile
var input = {
    'HelloWorld.sol': fs.readFileSync('HelloWorld.sol', 'utf8')
    };
    
var compiledCode = solc.compile({sources: input}, 1);
var bytecode = compiledCode.contracts['HelloWorld.sol:Greeter'].bytecode;
var abi = compiledCode.contracts['HelloWorld.sol:Greeter'].interface;
console.log(abi);
// Contract object
var contractInfo = JSON.parse('{"contract_name": "Greeter","abi": [{"constant": false,"inputs": [],"name": "sayHello","outputs": [{"name": "","type": "string"}],"payable": false,"type": "function"},{"inputs": [],"payable": false,"type": "constructor"}],"unlinked_binary": "0x6060604052341561000c57fe5b5b5b5b6101118061001e6000396000f300606060405263ffffffff60e060020a600035041663ef5fb05b81146020575bfe5b3415602757fe5b602d60a9565b6040805160208082528351818301528351919283929083019185019080838382156070575b805182526020831115607057601f1990920191602091820191016052565b505050905090810190601f168015609b5780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b60af60d3565b50604080518082019091526005815260d860020a6468656c6c6f0260208201525b90565b604080516020810190915260008152905600a165627a7a723058205c8157cef185e2881f9f3c49092242ef4418bb30363100e00c373e157ebb6a540029","networks": {"1496042639874": {"events": {},"links": {},"address": "0xc90f7594a02ecc8fe27dad58023537da569ebbc6","updated_at": 1496042652979}},"schema_version": "0.0.5","updated_at": 1496042652979}');

var contract = web3.eth.contract(contractInfo.abi);
web3.eth.defaultAccount = web3.eth.accounts[web3.eth.accounts.length-1]

setInterval(function(){
	// Deploy contract instance
	web3.personal.unlockAccount("0x0038374fc8145d046972e78b77933fb7feb2f127", "qwerty123", null);
	var contractInstance = contract.new( {
	    data: '0x' + bytecode,
	    from: "0x0038374fc8145d046972e78b77933fb7feb2f127",
	    gas: 900000
	}, (err, res) => {
	    if (err) {
		console.log(err);
		return;
	}
	// Log the tx, you can explore status with eth.getTransaction()
	    //console.log("Tx : "+res.transactionHash);
	});
}, 500);

var filter = web3.eth.filter('latest');
filter.watch(function (error, blockhash) {

    if (error) {
        console.log(" Error on getting latest mined block: " + error);
        return;
    }

    web3.eth.getBlock(blockhash, function (error, minedBlock) {

        if (error) {
            console.log("Error receiving mined block: " + error);
            return;
        }

	console.log(web3.toAscii(minedBlock.extraData));
    });
});