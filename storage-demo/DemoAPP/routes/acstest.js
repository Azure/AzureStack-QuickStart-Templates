var express = require('express');
var azure = require('azure-storage');
const util = require('util');
var router = express.Router();
var Config = require('./config');
var conf = new Config();

router.post('/', function (req, res) {
	var account = req.body.account;
	var key = req.body.key;
	var host = req.body.host;
	var tableSvc = azure.createTableService(account, key, account + ".table." + host);
	// try to create the test cases log table as a testing of connection and authentication
	tableSvc.createTableIfNotExists(conf.testTaskTable, function(error, response){
		var title = "Azure (Stack) Storage Testing Wizard Result";
		var code = 200;
		var message = "";
		if(!error){// create okay
			// HTTP Request /runtest to Start testing
			var http = require('http');
			var querystring = require('querystring');
			var caseNames = new Array();
			for (item in conf.testCases){// prepare test case names for running
				caseNames.push(conf.testCases[item].name);
			}
			var contents = querystring.stringify({
				"key": key,
				"account": account,
				"host": host,
				"cases": caseNames
			});
			var app = require('../app');
			var options = {
				host: '127.0.0.1',
				port: app.get('port'),
				path: '/runtest',
				method: 'POST',
				headers: {
					'Content-Type': 'application/x-www-form-urlencoded',
					'Content-Length': contents.length
				}
			};
			var re = http.request(options, function(res){
				res.on("data",function(r){
					console.log(r);
				});
			});
			re.write(contents);
			re.end();

			res.render('acstest', { "title": title, "cases":conf.testCases,"host":host, "account":account, "key":key});
		}
		else{// Error
			console.log(error);
			if(error.code == "AuthenticationFailed"){
				title = "Account Authentication Failed";
				code = 403;
				message = error.message;
			}
			else if(error.code == "ENOTFOUND"){
				title = "Account Name Not Found";
				code = 404;
				message = "The specified account name \""+account+"\" does not exist";
			}
			else{//unknown error
				title = "Error";
				code = 500;
				message = util.inspect(error);
			}
			res.render('error', { "title": title, "message": message, "code":code});
		}
	});
});

module.exports = router;