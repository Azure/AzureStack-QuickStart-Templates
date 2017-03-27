var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function (account, key, host) {
	var queueSvc = azure.createQueueService(account, key, account + ".queue." + host);
	queueSvc.getMessages(conf.queueName, { maximumExecutionTimeInMs: conf.caseInterval }, function (error, result, response) {
		var testCase = new TestCase(account, key, __filename, host);
		if (!error && result && result[0]) {
			var message = result[0];
			testCase.log(0, util.inspect(result));
			queueSvc.deleteMessage(conf.queueName, message.messageId, message.popReceipt, { maximumExecutionTimeInMs: conf.caseInterval }, function (error, response) {
				if (error) {
					testCase.log(1, util.inspect(error));
				}
			});
		}
		else {
			testCase.log(1, util.inspect(error));
		}
	});
}