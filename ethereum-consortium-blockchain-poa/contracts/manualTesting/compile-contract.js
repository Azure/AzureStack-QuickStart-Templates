// Import modules
solc = require('solc')
fs  = require('fs'); 


var originalContract = fs.readFileSync("..\\contracts\\SimpleValidatorSet.sol", 'utf8');
var result = originalContract.replace(/0x1111111111111111111111111111111111111111/g, "address(0x006a1a9b464a7808b0a2645ea62c15eb33615e29), address(0x00dd2ecedfc0034ace4f59375d5836165c72b492)");
var result = result.replace(/0x0000000000000000000000000000000000000000/g, "0x001543793efb9a0c9201E41E99DC9F4495C277Cc");
fs.writeFileSync("SimpleValidatorSet.sol", result, 'utf8');

var originalContract = fs.readFileSync("..\\contracts\\AdminValidatorSet.sol", 'utf8');
var result = originalContract.replace(/validatorCapacity = 13;/g, "validatorCapacity = 2;");
fs.writeFileSync("AdminValidatorSet.sol", result, 'utf8');

// Load contract into memory and compile
var input = {
    'TestValidatorSet.sol': fs.readFileSync('..\\contracts\\TestValidatorSet.sol', 'utf8'),
    'SimpleValidatorSet.sol': fs.readFileSync('.\\SimpleValidatorSet.sol', 'utf8'),
    'AdminValidatorSet.sol': fs.readFileSync('.\\AdminValidatorSet.sol', 'utf8'),
    'Utils.sol': fs.readFileSync('..\\contracts\\Utils.sol', 'utf8'),
    'Admin.sol': fs.readFileSync('..\\contracts\\Admin.sol', 'utf8'),
    'SafeMath.sol': fs.readFileSync('..\\contracts\\SafeMath.sol', 'utf8')
    };
    
var compiledCode = solc.compile({sources: input}, 1);
var bytecode = compiledCode.contracts['AdminValidatorSet.sol:AdminValidatorSet'].bytecode;
var abi = compiledCode.contracts['AdminValidatorSet.sol:AdminValidatorSet'].interface;

console.log(abi)
var fs = require('fs')
fs.readFile("demo-spec.json", 'utf8', function (err,data) {
  if (err) {
    return console.log(err);
  }
  var result = data.replace(/CONTRACT_BYTE_CODE/g, bytecode);

  fs.writeFile("spec.json", result, 'utf8', function (err) {
     if (err) return console.log(err);
  });
});

  fs.writeFile("abi.txt", abi, 'utf8', function (err) {
     if (err) return console.log(err);
  });