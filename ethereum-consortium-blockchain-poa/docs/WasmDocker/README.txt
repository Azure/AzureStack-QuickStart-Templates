The below instructions and related files are to simplify the deployment of "Step 5" in the Parity provided tutorial account.
Please read through this tutorial to understand what it is trying to achieve, and then use the steps below to deploy the token contract.
https://github.com/paritytech/pwasm-tutorial


In order to deploy the tutorial Wasm Contract 

1. ssh into one of the validator nodes
    a. ssh command can be found in the azure deployment for the resource group
    b. ex. [ssh -p 4000 user@devg433gg-dns-reg1.eastus.cloudapp.azure.com]
2. create a new folder named "tutorial", 
    a. [mkdir tutorial]
    b. [cd tutorial]
3. copy "Dockerfile" into this new folder
    a. ex. [vi Dockerfile]
    b. go into "insert" mode in vi by pressing "i"
    c. then paste the contents of the Dockerfile
    d. save the file by pressing the "ESC" key, and then type in ":wq"
4. Next, build the Docker image (Takes 5 to 10 minutes)
    a. [sudo docker build -t wasmtutorial:latest .]  - Be sure to include the period at the end of that command
5. Start the Docker image in interactive mode.
    a. [sudo docker run -it -v /opt/parity:/opt/parity wasmtest:latest /bin/bash]
    b. FYI - The "-v /opt/parity:/opt/parity" portion of the command maps the host parity folder to the docker image, so it can use the IPC api to communicate with parity
6. Deploy the Contract.
    a. copy the contents of the DeployContract.js file into a file on the docker image
    b. the run [node DeployContract.js "PASSWORD"] - replaceing "PASSWORD" with a new password that you want to use in the future to transfer the tokens with the new account that will be created
    c. the output of the DeployContract.js script will be "New Account #", "Contract Address", and the "Contract ABI".