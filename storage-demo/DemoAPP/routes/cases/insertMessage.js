var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function(account, key, host){
	var queueSvc = azure.createQueueService(account, key, account + ".queue." + host);
	for(var i = 0; i < 10; i++){
		queueSvc.createMessage(conf.queueName, "Hello Azure Stack " + i, {maximumExecutionTimeInMs: conf.caseInterval}, function (error) {
			var testCase = new TestCase(account, key, __filename, host);
			if(!error){
				testCase.log(0, "Messages created Successfully.");
			}
			else{
				testCase.log(1, util.inspect(error));
				return;
			}
		});
	}
}