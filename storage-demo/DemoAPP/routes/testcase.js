var azure = require('azure-storage');
var Config = require('./config');
var conf = new Config();
function TestCase(account, key, casename, host) {
	this.account = account;
	this.host = host;
	this.key = key;
	this.casename = casename.split("\\").pop().split(".")[0];
	this.tableSvc = azure.createTableService(this.account, this.key, this.account + ".table." + this.host);
	this.error = false;
	this.success = false;
	this.tableSvc.retrieveEntity(conf.testTaskTable, conf.testTaskTablePartitionKey, this.casename, function (error, result, response) {
		if (!error) {
			this.error = (result.error._ == 1);
			this.success = (result.error._ == 0);
		}
	});
}

TestCase.prototype.clearLog = function () {
	var entGen = azure.TableUtilities.entityGenerator;

	for (item in conf.testCases) {// prepare test case names for running
		var task = {
			PartitionKey: entGen.String(conf.testTaskTablePartitionKey),
			RowKey: entGen.String(conf.testCases[item].name)
		};
		this.tableSvc.deleteEntity(conf.testTaskTable, task, function (error, response) { });
	}

}

// Logging function
TestCase.prototype.log = function (error, message) {
	this.error = (error == 1);
	this.success = (error == 0);
	var entGen = azure.TableUtilities.entityGenerator;
	var task = {
		PartitionKey: entGen.String(conf.testTaskTablePartitionKey),
		RowKey: entGen.String(this.casename),
		message: entGen.String(message),
		error: error
	};
	this.tableSvc.insertOrReplaceEntity(conf.testTaskTable, task, function (error, result, response) { });
};

module.exports = TestCase;