// Import modules
solc = require('solc')
fs = require('fs');

// Load contract into memory and compile
var input = {
  'transactionPermissionTest.sol': fs.readFileSync('transactionPermissionTest.sol', 'utf8')
};

var compiledCode = solc.compile({ sources: input }, 1);
var bytecode = compiledCode.contracts['transactionPermissionTest.sol:TestOOG'].bytecode;
var abi = compiledCode.contracts['transactionPermissionTest.sol:TestOOG'].interface;

console.log(abi)

fs.writeFile("bytecode.txt", bytecode, 'utf8', function (err) {
  if (err) return console.log(err);
});

fs.writeFile("abi.txt", abi, 'utf8', function (err) {
  if (err) return console.log(err);
});