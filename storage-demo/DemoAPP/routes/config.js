function Config(){
	// Table for saving test cases running status and outputs
	this.testTaskTable = "ACSTestCases";
	// PartitionKey for the cases
	this.testTaskTablePartitionKey = "testcase";
	// Sleeping time in milli-seconds between each test case
	// Relatively small number will result in inconsistency, but it's okay for testing
	this.caseInterval = 1500;


	// Below are test configurations
	// Table
	this.tableName = "theacstesttable"; // Must be different with this.testTaskTable
	this.tablePartitionKey = "testPartition";
	this.tableRowKey = "testRowID";

	// Blob
	this.containerName = "acstestcontainer";
	//this.blobName = "acstestblob";
	//this.appendBlobName = "acstestappendblob";
	this.blobFile = "msft.png"; // relative path from application root directory
	this.appendBlobFile = "package.json"; // relative path from application root directory

	// Queue
	this.queueName = "acstestqueue";

	// All test cases
	// 'name' must be unique while 'desc' could be any description string that will be displayed on the portal
	// 'name' must match js file name under /routes/cases/ folder
	this.testCases = [
		{'name':'createContainer', 'desc':'Create a Blob Container'},
		{'name':'createAppendBlob', 'desc':'Create a new append Blob from a local file'},
		{'name':'appendBlob', 'desc':'Appends to an append blob from a text string'},
		{'name':'createBlob', 'desc':'Create a new block Blob from a local file'},
		{'name':'deleteBlob', 'desc':'Delete the block Blob'},
		{'name':'deleteContainer', 'desc':'Delete the Blob container'},
		{'name':'createTable', 'desc':'Create a new Table'},
		{'name':'insertEntity', 'desc':'Add an entity to the Table'},
		{'name':'updateEntity', 'desc':'Update the above entity'},
		{'name':'retrieveEntity', 'desc':'Retrive the entity by key'},
		{'name':'deleteEntity', 'desc':'Delete the entity'},
		{'name':'deleteTable', 'desc':'Delete the Table'},
		{'name':'createQueue', 'desc':'Create a Queue'},
		{'name':'insertMessage', 'desc':'Insert 10 messages into the Queue'},
		{'name':'peekMessage', 'desc':'Peek at the message in the front of the Queue'},
		{'name':'updateMessage', 'desc':'Update the message in the front of the Queue'},
		{'name':'dequeueMessage', 'desc':'Dequeue the next message'},
		{'name':'countMessage', 'desc':'Get the Queue length'},
		{'name':'deleteQueue', 'desc':'Delete the Queue'}
	];
}
module.exports = Config;