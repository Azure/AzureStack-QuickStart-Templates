//================================================================================
// Compiles the validator list solidity smart contract and generates a bytecode.
//================================================================================
var contractABIBlobName = process.argv[2];
// Import modules
solc = require('solc')
fs  = require('fs'); 


// Load contract into memory and compile
const input = {
    'AdminValidatorSet.sol': fs.readFileSync('AdminValidatorSet.sol', 'utf8'),
    'SimpleValidatorSet.sol': fs.readFileSync('SimpleValidatorSet.sol', 'utf8'),
    'Utils.sol': fs.readFileSync('Utils.sol', 'utf8'),
    'Admin.sol': fs.readFileSync('Admin.sol', 'utf8'),
    'SafeMath.sol': fs.readFileSync('SafeMath.sol', 'utf8')
    };
    
const compiledCode = solc.compile({sources: input}, 1);
const bytecode = compiledCode.contracts['AdminValidatorSet.sol:AdminValidatorSet'].bytecode;
const abi = compiledCode.contracts['AdminValidatorSet.sol:AdminValidatorSet'].interface;

// Write the ABI to a file for easy reference
fs.writeFileSync(contractABIBlobName, abi);

console.log(bytecode);


