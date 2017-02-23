var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function(account, key, host){
	var tableSvc = azure.createTableService(account, key, account + ".table." + host);
	var entGen = azure.TableUtilities.entityGenerator;
	var task = {
		PartitionKey: entGen.String(conf.tablePartitionKey),
		RowKey: entGen.String(conf.tableRowKey),
		Data: entGen.String("Hello Azure Stack TP2")
	};
	tableSvc.replaceEntity(conf.tableName, task, {maximumExecutionTimeInMs: conf.caseInterval}, function (error, result, response) {
		var testCase = new TestCase(account, key, __filename, host);
		if(!error){
			testCase.log(0, util.inspect(response));
		}
		else{//error
			testCase.log(1, util.inspect(error));
		}
	});
}