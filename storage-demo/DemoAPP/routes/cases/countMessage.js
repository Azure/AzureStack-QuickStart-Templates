var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function(account, key, host){
	var queueSvc = azure.createQueueService(account, key, account + ".queue." + host);	
	queueSvc.getQueueMetadata(conf.queueName, {maximumExecutionTimeInMs: conf.caseInterval}, function(error, result, response){
		var testCase = new TestCase(account, key, __filename, host);
		if(!error){
			testCase.log(0, util.inspect(result));
			// Queue length is available in result.approximateMessageCount
		}
		else{
			testCase.log(1, util.inspect(error));
		}
	});

}