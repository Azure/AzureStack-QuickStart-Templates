var azure = require('azure-storage');
const util = require('util');
var Config = require('../config');
var conf = new Config();
var TestCase = require('../testcase');
module.exports = function (account, key, host) {
	var blobSvc = azure.createBlobService(account, key, account + ".blob." + host);
	blobSvc.appendFromText(conf.containerName,
		conf.appendBlobFile,
		"\n\nThis line is appended by the magical appendFromText() function of Append Blob",
		{ maximumExecutionTimeInMs: conf.caseInterval },
		function (error, result, response) {
			var testCase = new TestCase(account, key, __filename, host);
			if (!error) {

				blobSvc.getBlobToText(conf.containerName, conf.appendBlobFile, { maximumExecutionTimeInMs: conf.caseInterval }, function (error, text, blockBlob, response) {
					if (!error) {
						testCase.log(0, "Content of the Blob in Text is:\n" + text);
					}
					else {
						testCase.log(1, util.inspect(error));
					}


				});
			}
			else {//error
				testCase.log(1, util.inspect(error));
			}
		});
}
