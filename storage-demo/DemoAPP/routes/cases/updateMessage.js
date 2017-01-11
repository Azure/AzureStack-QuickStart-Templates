var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function (account, key, host) {
	var queueSvc = azure.createQueueService(account, key, account + ".queue." + host);
	queueSvc.getMessages(conf.queueName, function (error, result, response) {
		var testCase = new TestCase(account, key, __filename, host);
		if (!error && result && result[0]) {
			var message = result[0];
			queueSvc.updateMessage(conf.queueName, message.messageId, message.popReceipt, 10, {
				messageText: message.messageText + " Updated",
				maximumExecutionTimeInMs: conf.caseInterval
			},
				function (error, result, response) {
					if (!error) {
						testCase.log(0, util.inspect(result));
					}
					else {
						testCase.log(1, util.inspect(error));
					}
				});
		}
		else {
			testCase.log(1, util.inspect(error));
		}
	});
}