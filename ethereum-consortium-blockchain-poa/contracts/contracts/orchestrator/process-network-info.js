// Parses the JSON and writes each section to separate files for hosting in AZ Storage
var NETWORK_INFO_FILE_NAME = process.argv[2];
var PARITY_SPEC_BLOB_NAME = process.argv[3];
var VALSET_CONTRACT_BLOB_NAME = process.argv[4];
var ADMIN_CONTRACT_BLOB_NAME = process.argv[5];
var ADMIN_CONTRACT_ABI_BLOB_NAME = process.argv[6];

var fs = require('fs');
var networkinfo = JSON.parse(fs.readFileSync(NETWORK_INFO_FILE_NAME, 'utf8'));

fs.writeFileSync(PARITY_SPEC_BLOB_NAME, networkinfo.paritySpec)
fs.writeFileSync(VALSET_CONTRACT_BLOB_NAME, networkinfo.valSetContract)
fs.writeFileSync(ADMIN_CONTRACT_BLOB_NAME, networkinfo.adminContract)
fs.writeFileSync(ADMIN_CONTRACT_ABI_BLOB_NAME, networkinfo.adminContractABI)