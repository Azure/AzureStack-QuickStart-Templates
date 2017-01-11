var azure = require('azure-storage');
const util = require('util');
var TestCase = require('../testcase');
var Config = require('../config');
var conf = new Config();
module.exports = function(account, key, host){
	var blobSvc = azure.createBlobService(account, key, account + ".blob." + host);
	blobSvc.deleteContainer(conf.containerName, {maximumExecutionTimeInMs: conf.caseInterval}, function (error, result, response) {
		var testCase = new TestCase(account, key, __filename, host);
		if(!error){//success
			testCase.log(0, util.inspect(result));
		}
		else{//error
			testCase.log(1, util.inspect(error));
		}
	});
}
