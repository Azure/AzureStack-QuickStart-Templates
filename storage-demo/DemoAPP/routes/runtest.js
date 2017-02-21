var express = require('express');
var router = express.Router();
var TestCase = require('./testcase');
var Config = require('./config');
var conf = new Config();

var account, key, cases, host, idx = 0;
//
// Called every conf.caseInterval milliseconds
//
function runNext(){
	if(idx < cases.length){
		var test = require("./cases/" + cases[idx]);
		test(account, key, host);
		idx ++;
		if(idx < cases.length){
			setTimeout(runNext, conf.caseInterval);
		}
	}
}

router.post('/', function (req, res) {
	idx = 0;
	account = req.body.account;
	key = req.body.key;
	host = req.body.host;
	var testCase = new TestCase(account, key, __filename, host);
	testCase.clearLog();
	cases = req.body.cases;
	runNext();
});


module.exports = router;