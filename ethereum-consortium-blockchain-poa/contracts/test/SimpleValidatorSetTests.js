import expectThrow from './helpers/expectThrow';
var TestValidatorSet = artifacts.require("./TestValidatorSet.sol");

var validatorIDList = ['0x00f4131a087bfc65bcb0edc795c468d50b0c9161', '0x10f4131a087bfc6dbcb0edc795c468d50b0c9161', '0x23f4131a087bfc6dbcb0edc795c468d50b0c9145', '0x88f4131a087bfc6dbcb0edc795c468d50b0c9188'];
var adminIDList = ['0x0004131a087bfc65bcb0edc795c468d50b0c9100', '0x11f4131a087bfc6dbcb0edc795c468d50b0c9111', '0x22f4131a087bfc6dbcb0edc795c468d50b0c9122'];

contract('TestValidatorSet', async (accounts) => {
    
    it("should start with 3 accounts", async () => {
        let instance = await TestValidatorSet.deployed();
        let vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);
    });
    
    it("should add a validator when addValidators is called from a current validator", async () => {
        let instance = await TestValidatorSet.deployed();

        await instance.addValidators([validatorIDList[0]], adminIDList[0], {from: web3.eth.accounts[0]});
        
        // Should fail if change hasn't yet been finalized 
        expectThrow(instance.addValidators([validatorIDList[1]], adminIDList[1], {from: web3.eth.accounts[0]}));

        var vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);
        
        // first call to finalize will add the first account to the list
        await instance.finalizeChange();
        vals = await instance.getValidators.call();
        assert.equal(vals.length, 4, "expected 4 validators found " + vals.length);
        assert.equal(vals.indexOf(validatorIDList[0]) > 0, true, "expected new validator to be present");
        
        // Can now add a new set of validators
        await instance.addValidators([validatorIDList[1], validatorIDList[2]], adminIDList[1], {from: web3.eth.accounts[0]})

        await instance.finalizeChange();
        vals = await instance.getValidators.call();
        assert.equal(vals.length, 6, "expected 6 validators found " + vals.length);
        assert.equal(vals.indexOf(validatorIDList[1]) > 0, true, "expected new validator to be present");
        assert.equal(vals.indexOf(validatorIDList[2]) > 0, true, "expected new validator to be present");
    });

    it("should fail if validator calls addValidators and is not active validator", async () => {
        let instance = await TestValidatorSet.deployed();
        expectThrow(instance.addValidators([validatorIDList[0]], 
                                            adminIDList[0],
                                            {from: web3.eth.accounts[1]}));
    });
    
    it("should remove a validator when removeValidators is called from a current validator", async () => {
        let instance = await TestValidatorSet.deployed()

        await instance.removeValidators([validatorIDList[0]], 
                                        adminIDList[0], 
                                        {from: web3.eth.accounts[0]});

        // Should fail if change hasn't yet been finalized 
        expectThrow(instance.removeValidators([validatorIDList[1]], 
                                                adminIDList[1], 
                                                {from: web3.eth.accounts[0]}));
        var vals = await instance.getValidators.call();
        assert.equal(vals.length, 6, "expected 6 validators found " + vals.length);

        // first call to finalize will remove the first account
        await instance.finalizeChange();
        vals = await instance.getValidators.call();
        assert.equal(vals.length, 5, "expected 5 validators found " + vals.length);
        assert.equal(vals.indexOf(web3.eth.accounts[0]) > 0, true, "expected truffle dev account to still be present");
        assert.equal(vals.indexOf(validatorIDList[0]), -1, "expected validator to be removed");

        // Should fail if one of the validators isn't owned by admin
        expectThrow(instance.removeValidators([validatorIDList[1], web3.eth.accounts[0]], 
                                                adminIDList[1],
                                                {from: web3.eth.accounts[0]}));
        
        // Should fail if validator list contains dupes
        expectThrow(instance.removeValidators([validatorIDList[1], validatorIDList[1]], 
                                                adminIDList[1], 
                                                {from: web3.eth.accounts[0]}));

        // Should fail if validator not present
        expectThrow(instance.removeValidators([validatorIDList[1], validatorIDList[3]], 
                                                adminIDList[1], 
                                                {from: web3.eth.accounts[0]}));
        // Should fail if admin not present
        expectThrow(instance.removeValidators([validatorIDList[1], validatorIDList[2]], 
                                                adminIDList[2], 
                                                {from: web3.eth.accounts[0]}));
        // remove two validators at once 
        await instance.removeValidators([validatorIDList[1], validatorIDList[2]], 
                                        adminIDList[1], 
                                        {from: web3.eth.accounts[0]});

        // second call to finalize will remove two validators
        await instance.finalizeChange();
        vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);
        assert.equal(vals.indexOf(web3.eth.accounts[0]) > 0, true, "expected truffle dev account to still be present");
        assert.equal(vals.indexOf(validatorIDList[1]), -1, "expected validator to be removed");
        assert.equal(vals.indexOf(validatorIDList[2]), -1, "expected validator to be removed");
    });

    it("should not allow validator count to drop below 2", async () => {
        let instance = await TestValidatorSet.deployed()

        await instance.removeValidators(["0x007a5dc2a434dF5e7f3F40af424F7Ba521b294b7"], 
                                        web3.eth.accounts[0],
                                        {from: web3.eth.accounts[0]});        
        await instance.finalizeChange();
        
        // Should fail if validators would drop below 2
        expectThrow(instance.removeValidators(["0x00933b6FF79899F3B5B56E28725bbEB5be8f43e1"],
                                                web3.eth.accounts[0],
                                                {from: web3.eth.accounts[0]}));
    });

    it("should not allow the same validator to be added twice", async () => {
        let instance = await TestValidatorSet.deployed()
        
        expectThrow(instance.addValidators(["0x00933b6FF79899F3B5B56E28725bbEB5be8f43e1"],
                                                web3.eth.accounts[0],
                                                {from: web3.eth.accounts[0]}));
    });
});

  