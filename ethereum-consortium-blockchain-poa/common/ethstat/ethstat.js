
var Web3 = require('web3');
var crypto = require("crypto");
var request = require('request');
var appjson = require('./version.json');
var fs = require('fs');
var util = require('util');

var logTypePendingTransaction = "PendingTransaction";
var logTypeMinedBlock = "MinedBlock";
var logTypeMinedTransaction = "MinedTransaction";

function sign(message,secret) {
    return crypto.createHmac('sha256', new Buffer(secret, 'base64')).update(message, 'utf-8').digest('base64'); 
}

function post(headers,url,data) {    
    request.post({url: url, headers: headers, body:data}, function (error, response, body) { 
        if (error || response.statusCode != 200) {
            console.log("Log analytics error response: " + body);
        }
    });
}

function sendlogs(customerId, sharedKey, data, logType) {
    
    var method = "POST";
    var contentType = "application/json";
    var resource = "/api/logs";
    var rfc1123date = new Date().toUTCString();
    var xmsDate = "x-ms-date:" + rfc1123date

    data = JSON.stringify(data);
    var contentLength = Buffer.byteLength(data,'utf8');

    // build authorization signature
    var stringToHash = method + "\n" + 
                        contentLength + "\n" + 
                        contentType + "\n" + 
                        xmsDate  + "\n" + 
                        resource 
    
    var hashedString = sign(stringToHash,sharedKey);
    var signature = "SharedKey " + customerId + ":" + hashedString;    
    
    // send data as http request
    var url = "https://" + customerId + ".ods.opinsights.azure.com" + resource + "?api-version=2016-04-01"
    var headers = { 
        "content-type": contentType, 
        "Authorization": signature, 
        "Log-Type": logType, 
        "x-ms-date": rfc1123date      
    }
    post(headers, url, data);
}

// create mined block data formatted for log analytics(OMS)
function createMinedBlockLog(blockInfo) {

    var transactionsCount = (blockInfo.transactions) ? blockInfo.transactions.length : 0;
    var unclesCount = (blockInfo.uncles) ? blockInfo.uncles.length : 0;

    var minedBlockStat = {  
        NodeProvider: rpcAddress,  
        ListenerHostName: ipAddr,  
        ListenerReceivedTimestamp: new Date().toISOString(),
        BlockHash: blockInfo.hash,
        BlockNumber: blockInfo.number,
        BlockParentHash: blockInfo.parentHash,
        BlockNonce: blockInfo.nonce,
        BlockMiner: blockInfo.miner,
        BlockTimestamp: new Date(Number(blockInfo.timestamp) * 1000).toISOString(),
        BlockTransactionCount: transactionsCount,
        BlockUncleCount: unclesCount,
        BlockExtraData: blockInfo.extraData,
        BlockGasLimit: blockInfo.gasLimit,
        BlockGasUsed: blockInfo.gasUsed,
        BlockDifficulty: Number(blockInfo.difficulty),
        ChainTotalDifficulty: Number(blockInfo.totalDifficulty),
        ExtraData: web3.toAscii(blockInfo.extraData)
    }; 

    return minedBlockStat;
}

// create transaction data formatted for log analytics(OMS)
function createTransactionLog(receipt) {
    
    var transaction = {  
        NodeProvider: rpcAddress,  
        ListenerHostName: ipAddr,  
        ListenerReceivedTimestamp: new Date().toISOString(),
        TransactionHash: receipt.transactionHash,
        BlockHash: receipt.blockHash,
        BlockNumber: receipt.blockNumber,
        TransactionIndex: receipt.transactionIndex,
        FromAddress: receipt.from,
        ToAddress: (receipt.to) ? receipt.to : "",
        CumulativeGasUsed: receipt.cumulativeGasUsed,
        GasUsed: receipt.gasUsed,
        ContractAddress: (receipt.contractAddress) ? receipt.contractAddress : ""
    }; 

    return transaction;
}

// create pending transaction data formatted for log analytics(OMS)
function createPendingTransactionLog(transaction) {
    
    var pendingTran = {  
        NodeProvider: rpcAddress,  
        ListenerHostName: ipAddr,  
        ListenerReceivedTimestamp: new Date().toISOString(),
        TransactionHash: transaction.hash,
        TransactionNonce: transaction.nonce,
        FromAddress: transaction.from,
        ToAddress: transaction.to,
        Value: Number(web3.fromWei(transaction.value, 'ether')),
        GasPrice: Number(web3.fromWei(transaction.gasPrice, 'gwei')),
        Gas: transaction.gas,
        Input: transaction.input
    }; 

    return pendingTran;
}

// Send block information to OMS
function sendBlock(block) {

    var minedBlockLogData = createMinedBlockLog(block)
    sendlogs(customerId, sharedKey, minedBlockLogData, logTypeMinedBlock);
}

// Send transactional information to OMS
function sendTransactions(transactions) {

    if (!transactions || transactions.length==0) {
        return;
    }

    for (t of transactions) {
        web3.eth.getTransactionReceipt(t, function(error, receipt){
            
            if (error) {
              console.log("Error receiving transaction receipt: " + error);
              return;
            }
    
            var transaction = createTransactionLog(receipt);
            sendlogs(customerId, sharedKey, transaction, logTypeMinedTransaction);
          });
    }
}   

function sendPendingTransaction(transaction) {
    
    if (!transaction) {
        return;
    }

    var pendingTransaction = createPendingTransactionLog(transaction)
    sendlogs(customerId, sharedKey, pendingTransaction, logTypePendingTransaction);
}
    

// Log unhandled exceptions
process.on('uncaughtException', err => { console.log("Unhandled exception thrown: " + err); throw err;});
process.on('unhandledRejection', err => { console.log("Unhandled rejection thrown: " + err); throw err;});

// get inputs
var ipAddr = process.argv[2];
var rpcPort = process.argv[3]
var sharedKey = process.argv[4];
var customerId = process.argv[5];
var logFile = process.argv[6]

console.log("Inputs: CustomerId:" + customerId + ", SharedKey:" + sharedKey + ", Ip Address:" + ipAddr + " , RPC port: "+ rpcPort + ", Log file: " + logFile);

var rpcAddress = ipAddr + ":" + rpcPort;

// Set logging
var log_file = fs.createWriteStream(logFile, {flags : 'a'});
var log_stdout = process.stdout;

console.log = function(d) { //
  log_file.write(util.format(d) + '\n');
  log_stdout.write(util.format(d) + '\n');
};

console.log(`Started ethstat - Ver.${appjson.version}`);

// init web3
var web3 = new Web3();
web3.setProvider(new Web3.providers.HttpProvider('http://localhost:' + rpcPort));
console.log("Initialized web3.");

//set filter for getting notification on mined block 
var filter = web3.eth.filter('latest');
filter.watch(function (error, blockhash) {
    
    if (error) {
        console.log(" Error on getting latest mined block: " + error);
        return;
    }

    web3.eth.getBlock(blockhash, function(error, minedBlock){
        
        if (error) {
          console.log("Error receiving mined block: " + error);
          return;
        }

        sendBlock(minedBlock)
        sendTransactions(minedBlock.transactions);
      });
});
console.log("Added a filter for receiving mined block.");

//set filter for getting notification on pending transactions 
var filter = web3.eth.filter('pending');
filter.watch(function (error, transactionHash) {

    if (error) {
        console.log("Error on getting pending transaction: " + error);
        return;
    }

    web3.eth.getTransaction(transactionHash, function(error, transaction){
        
        if (error) {
          console.log("Error receiving pending transaction: " + error);
          return;
        }

        sendPendingTransaction(transaction);
      });
});
console.log("Added a filter for receiving pending transactions.");


