var express = require('express');
var router = express.Router();
var azure = require('azure-storage');
var Config = require('./config');
var conf = new Config();

router.all('/', function (req, res) {
	var tableSvc = azure.createTableService(req.body.account, req.body.key, req.body.account + ".table." + req.body.host);
	var query = new azure.TableQuery()
	  .where('PartitionKey eq ?', conf.testTaskTablePartitionKey);
	tableSvc.queryEntities(conf.testTaskTable, query, null, function(error, result, response) {
		var rt = new Object();

		if(!error) {
			for(item in result.entries){
				var tmp = result.entries[item];
				rt[tmp.RowKey._] = new Array();
				rt[tmp.RowKey._].push(tmp.error._);
				rt[tmp.RowKey._].push(tmp.message._);

			}
			res.send(JSON.stringify(rt));
		}
	});
});
module.exports = router;