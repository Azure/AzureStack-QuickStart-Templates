var azure = require('azure-storage');
const util = require('util');
var TestCase = require('../testcase');
var Config = require('../config');
var conf = new Config();
module.exports = function(account, key, host){
	var queueSvc = azure.createQueueService(account, key, account + ".queue." + host);
	queueSvc.deleteQueue(conf.queueName, {maximumExecutionTimeInMs: conf.caseInterval}, function(error, response){
		var testCase = new TestCase(account, key, __filename, host);
		if(!error){//success
			testCase.log(0, util.inspect(response));
		}
		else{//error
			testCase.log(1, util.inspect(error));
		}
	});
}
