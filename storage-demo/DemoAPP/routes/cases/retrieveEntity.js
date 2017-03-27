var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function(account, key, host){
	var tableSvc = azure.createTableService(account, key, account + ".table." + host);
	tableSvc.retrieveEntity(conf.tableName, conf.tablePartitionKey, conf.tableRowKey, {maximumExecutionTimeInMs: conf.caseInterval}, function(error, result, response){
		var testCase = new TestCase(account, key, __filename, host);
		if(!error){
			testCase.log(0, util.inspect(result));
		}
		else{
			testCase.log(1, util.inspect(error));
		}
	});
}