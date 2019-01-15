var TestValidatorSet = artifacts.require(".\\contracts\\TestValidatorSet.sol");
var AdminValidatorSet = artifacts.require(".\\contracts\\AdminValidatorSet.sol");

module.exports = function(deployer) {
  deployer.deploy(TestValidatorSet);
  deployer.deploy(AdminValidatorSet);
};
