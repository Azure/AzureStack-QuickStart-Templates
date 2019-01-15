import expectThrow from './helpers/expectThrow';
var AdminValidatorSet = artifacts.require("./AdminValidatorSet.sol");

var validatorIDList = ['0x00f4131a087bfc65bcb0edc795c468d50b0c9161', '0x10f4131a087bfc6dbcb0edc795c468d50b0c9161', '0x23f4131a087bfc6dbcb0edc795c468d50b0c9145', '0x33f4131a087bfc65bcb0edc795c468d50b0c9133', '0x44f4131a087bfc6dbcb0edc795c468d50b0c9144', '0x55f4131a087bfc6dbcb0edc795c468d50b0c9155', '0x66f4131a087bfc65bcb0edc795c468d50b0c9166', '0x77f4131a087bfc6dbcb0edc795c468d50b0c9177', '0x88f4131a087bfc6dbcb0edc795c468d50b0c9188','0x99f4131a087bfc65bcb0edc795c468d50b0c9199', '0x1004131a087bfc6dbcb0edc795c468d50b0c9100', '0x1114131a087bfc6dbcb0edc795c468d50b0c9111', '0x2224131a087bfc6dbcb0edc795c468d50b0c9222','0x3334131a087bfc65bcb0edc795c468d50b0c9333', '0x4444131a087bfc6dbcb0edc795c468d50b0c9444', '0x5554131a087bfc6dbcb0edc795c468d50b0c9555'];

contract('AdminValidatorSet', async (accounts) => {
    
    it("should start with 1 admin", async () => {
        let instance = await AdminValidatorSet.deployed();
        let count = await instance.getAdminCount.call();
        let admins = await instance.getAdmins.call();
        assert.equal(count, 1, "expected 1 admin, found " + count);
        assert.equal(web3.eth.accounts[0], admins[0], "missing expected admin");
    });

    it("should let admins change their alias", async () => {
        let instance = await AdminValidatorSet.deployed();
        instance.updateAdminAlias("Satoshi", 
                                            {from: web3.eth.accounts[0]});
                      
        let alias = await instance.getAliasForAdmin.call(web3.eth.accounts[0]);
        assert.equal("Satoshi", alias, "change alias failed")                                                        
    });

    it("should let admin propose and vote for new admins", async () => {
        let instance = await AdminValidatorSet.deployed();
        let count = await instance.getAdminCount.call();
        let admins = await instance.getAdmins.call();
        assert.equal(count, 1, "expected 1 admin, found " + count);
        assert.equal(web3.eth.accounts[0], admins[0], "missing expected admin");
        var tx = "";

        // Should reject if admin already exists (nice try Craig...)
        expectThrow(instance.proposeAdmin(web3.eth.accounts[0], "Wright", 
        {from: web3.eth.accounts[0]}));

        // Should reject if voter not an admin
        expectThrow(instance.proposeAdmin(web3.eth.accounts[1], "Vitalik", 
                                            {from: web3.eth.accounts[1]}));

        await instance.proposeAdmin(web3.eth.accounts[1], "Vitalik", 
                                            {from: web3.eth.accounts[0]});
        
        admins = await instance.getAdmins.call();
        count = await instance.getAdminCount.call();
        assert.equal(count, 2, "expected 2 admins, found " + count);
        assert.equal(web3.eth.accounts[0], admins[0], "missing expected admin");
        assert.equal(web3.eth.accounts[1], admins[1], "missing expected admin");
        count = await instance.getProposedCount.call();
        assert.equal(count, 0, "expected 0 proposed admin, found " + count);
        
        // One vote is not majority (1/2)
        await instance.proposeAdmin(web3.eth.accounts[2], "Finney", 
                                            {from: web3.eth.accounts[0]});

        admins = await instance.getAdmins.call();
        count = await instance.getAdminCount.call();
        assert.equal(count, 2, "expected 2 admins, found " + count);
        assert.equal(web3.eth.accounts[0], admins[0], "missing expected admin");
        assert.equal(web3.eth.accounts[1], admins[1], "missing expected admin");
        count = await instance.getProposedCount.call();
        assert.equal(count, 1, "expected 1 proposed admin, found " + count);
        
        // Two votes is majority (2/2)
        await instance.voteFor(web3.eth.accounts[2], 
                                            {from: web3.eth.accounts[1]});

        admins = await instance.getAdmins.call();
        count = await instance.getAdminCount.call();
        assert.equal(count, 3, "expected 3 admins, found " + count);
        assert.equal(web3.eth.accounts[0], admins[0], "missing expected admin");
        assert.equal(web3.eth.accounts[1], admins[1], "missing expected admin");
        assert.equal(web3.eth.accounts[2], admins[2], "missing expected admin");
        count = await instance.getProposedCount.call();
        assert.equal(count, 0, "expected 0 proposed admin, found " + count);

        // One vote is not majority (1/3)
        await instance.proposeAdmin(web3.eth.accounts[3], "Gavin", 
                                            {from: web3.eth.accounts[0]});

        admins = await instance.getAdmins.call();
        count = await instance.getAdminCount.call();
        assert.equal(count, 3, "expected 3 admins, found " + count);
        count = await instance.getProposedCount.call();
        assert.equal(count, 1, "expected 1 proposed admin, found " + count);
        count = await instance.countOfVotesFor(web3.eth.accounts[3]);
        assert.equal(count, 1, "expected 1 voteFor, found " + count);

        // Admin cannot vote for the same admin twice
        expectThrow(instance.proposeAdmin(web3.eth.accounts[3], "Gavin", 
                                            {from: web3.eth.accounts[1]}));

        // Propose should fail since admin already proposed
        expectThrow(instance.proposeAdmin(web3.eth.accounts[3], "Gavin", 
                                            {from: web3.eth.accounts[1]}));

        // Two votes is majority (2/3)
        await instance.voteFor(web3.eth.accounts[3],
                                {from: web3.eth.accounts[1]});

        admins = await instance.getAdmins.call();
        count = await instance.getAdminCount.call();
        assert.equal(count, 4, "expected 4 admins, found " + count);
        assert.equal(web3.eth.accounts[0], admins[0], "missing expected admin");
        assert.equal(web3.eth.accounts[1], admins[1], "missing expected admin");
        assert.equal(web3.eth.accounts[2], admins[2], "missing expected admin");
        assert.equal(web3.eth.accounts[3], admins[3], "missing expected admin");
        let alias = await instance.getAliasForAdmin.call(web3.eth.accounts[3]);
        assert.equal("Gavin", alias, "change alias failed");
        count = await instance.getProposedCount.call();
        assert.equal(count, 0, "expected 0 proposed admin, found " + count);
    });

    it("should let admin add/remove validators up to limit", async () => {
        let instance = await AdminValidatorSet.deployed();
        let vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);

        await instance.addValidators([validatorIDList[0],
                                    validatorIDList[1],
                                    validatorIDList[2],
                                    validatorIDList[3],
                                    validatorIDList[4],
                                    validatorIDList[5],
                                    validatorIDList[6],
                                    validatorIDList[7],
                                    validatorIDList[8],
                                    validatorIDList[9],
                                    validatorIDList[10],
                                    validatorIDList[11],
                                    validatorIDList[12]],
                                    {from: web3.eth.accounts[1]});
        
        await instance.finalizeChange();

        vals = await instance.getValidators.call();
        assert.equal(vals.length, 16, "expected 16 validators found " + vals.length);
        
        // attempt to add 14th validator for a given admin
        expectThrow(instance.addValidators([validatorIDList[13]],
                                    {from: web3.eth.accounts[1]}));
        
        await instance.removeValidators([validatorIDList[0],
                                    validatorIDList[1],
                                    validatorIDList[2],
                                    validatorIDList[3],
                                    validatorIDList[4],
                                    validatorIDList[5],
                                    validatorIDList[6],
                                    validatorIDList[7],
                                    validatorIDList[8],
                                    validatorIDList[9],
                                    validatorIDList[10],
                                    validatorIDList[11],
                                    validatorIDList[12]],
                                    {from: web3.eth.accounts[1]});
        
        await instance.finalizeChange();

        vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);
    });

    it("should let admin add/remove the same validator multiple times", async () => {
        let instance = await AdminValidatorSet.deployed();
        let vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);

        await instance.addValidators([validatorIDList[13]],
                                    {from: web3.eth.accounts[1]});
        
        await instance.finalizeChange();

        vals = await instance.getValidators.call();
        assert.equal(vals.length, 4, "expected 4 validators found " + vals.length);
        
        await instance.removeValidators([validatorIDList[13],],
                                    {from: web3.eth.accounts[1]});
        
        await instance.finalizeChange();

        vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);
        await instance.addValidators([validatorIDList[13]],
                                    {from: web3.eth.accounts[1]});
        
        await instance.finalizeChange();

        vals = await instance.getValidators.call();
        assert.equal(vals.length, 4, "expected 4 validators found " + vals.length);
        
        await instance.removeValidators([validatorIDList[13],],
                                    {from: web3.eth.accounts[1]});
        
        await instance.finalizeChange();

        vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);
    });

    it("should not let non-admins add/remove validators", async () => {
        let instance = await AdminValidatorSet.deployed();
        let admins = await instance.getAdmins.call();
        assert.equal(admins.indexOf(web3.eth.accounts[4]), -1, "Test assumptions are incorrect: Expected admin not present");

        // Non-Admin
        let vals = await instance.getValidators.call();
        expectThrow(instance.addValidators([validatorIDList[0]],
                                    {from: web3.eth.accounts[4]}));
        expectThrow(instance.removeValidators([validatorIDList[0]],
                                    {from: web3.eth.accounts[4]}));
    });

    it("should let admin vote to remove admins", async () => {
        let instance = await AdminValidatorSet.deployed();
        let count = await instance.getAdminCount.call();
        assert.equal(count, 4, "expected 4 admin, found " + count);

        // Add a validator the admin about to be removed
        await instance.addValidators([validatorIDList[13]],
            {from: web3.eth.accounts[0]});

        await instance.finalizeChange();
        let vals = await instance.getValidators.call();
        assert.equal(vals.length, 4, "expected 4 validators found " + vals.length);

        // Setting up a voteFor and voteAgainst from admin0 (should be removed with admin) 
        // VoteFor
        await instance.proposeAdmin(web3.eth.accounts[4], "ToBeRemoved", 
                                            {from: web3.eth.accounts[0]});
        count = await instance.countOfVotesFor(web3.eth.accounts[4]);
        assert.equal(count, 1, "expected 1 voteFor, found " + count);

        // VoteAgainst
        await instance.voteAgainst(web3.eth.accounts[1],
            {from: web3.eth.accounts[0]});
        count = await instance.countOfVotesAgainst(web3.eth.accounts[1]);
        assert.equal(count, 1, "expected 1 voteAgainst, found " + count);
        // Expect no change since not majority
        count = await instance.getAdminCount.call();
        assert.equal(count, 4, "expected 4 admin, found " + count);

        // Admin can vote to remove themselves
        // One vote is not majority (1/4)
        await instance.voteAgainst(web3.eth.accounts[0],
            {from: web3.eth.accounts[0]});

        count = await instance.countOfVotesAgainst(web3.eth.accounts[0]);
        assert.equal(count, 1, "expected 1 voteAgainst, found " + count);

        count = await instance.getAdminCount.call();
        assert.equal(count, 4, "expected 4 admin, found " + count);

        // Two votes is not majority (2/4)
        await instance.voteAgainst(web3.eth.accounts[0],
            {from: web3.eth.accounts[2]});
        
        count = await instance.countOfVotesAgainst(web3.eth.accounts[0]);
        assert.equal(count, 2, "expected 2 voteAgainst, found " + count);

        count = await instance.getAdminCount.call();
        assert.equal(count, 4, "expected 4 admin, found " + count);

        // Three votes is majority (3/4) 
        await instance.voteAgainst(web3.eth.accounts[0],
            {from: web3.eth.accounts[3]});

        // call finalize to remove validators
        await instance.finalizeChange();

        count = await instance.getAdminCount.call();
        assert.equal(count, 3, "expected 3 admin, found " + count);
        let admins = await instance.getAdmins.call();
        assert.equal(admins.indexOf(web3.eth.accounts[0]) < 0, true, "expected admin to be removed");

        // Removing an admin will remove all the admin's validators
        vals = await instance.getValidators.call();
        assert.equal(vals.length, 3, "expected 3 validators found " + vals.length);

        // Removing an admin will remove all votes from that admin
        count = await instance.countOfVotesFor(web3.eth.accounts[4]);
        assert.equal(count, 0, "expected 0 voteFor, found " + count);
        count = await instance.countOfVotesAgainst(web3.eth.accounts[1]);
        assert.equal(count, 0, "expected 0 voteAgainst, found " + count);

        // Cannot vote against an admin that's not present
        expectThrow(instance.voteAgainst(web3.eth.accounts[0],
            {from: web3.eth.accounts[0]}));
    });
});

  