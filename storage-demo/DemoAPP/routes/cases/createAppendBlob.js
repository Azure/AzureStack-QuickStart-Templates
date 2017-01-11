var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function (account, key, host) {
	var blobSvc = azure.createBlobService(account, key, account + ".blob." + host);
	blobSvc.createAppendBlobFromLocalFile(conf.containerName, conf.appendBlobFile, conf.appendBlobFile, { maximumExecutionTimeInMs: conf.caseInterval }, function (error, result, response) {
		var testCase = new TestCase(account, key, __filename, host);
		if (!error) {
			testCase.log(0, util.inspect(result));
		}
		else {//error
			testCase.log(1, util.inspect(error));
		}
	});
}
