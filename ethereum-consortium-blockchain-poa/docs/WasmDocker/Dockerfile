# Node and NPM are required for the Rust WASM tutorial
FROM node:8.11.1

# Install basic utilities that will be needed
RUN apt-get update
RUN apt-get install -y vim less netcat-openbsd

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Update the $PATH environment variable to include the Rust bin folder
ENV PATH "$PATH:/root/.cargo/bin"

# Install remaining Rust components necessary to compile Webassembly contracts
RUN rustup install nightly-2018-06-28
RUN cargo install pwasm-utils-cli --bin wasm-build

# Create tutorial directory
WORKDIR /usr/src/tutorial

# Download the tutorial repository
RUN git clone https://github.com/paritytech/pwasm-tutorial.git

# Install required NPM modules for the tutorial
WORKDIR /usr/src/tutorial/pwasm-tutorial
RUN npm install

# Install last components required for "./build.sh" tutorial scripts
RUN rustup target add wasm32-unknown-unknown


#---------------------------------------------
#EXCLUDE BELOW BEFORE COMMIT TO Master
#---------------------------------------------

# Go into the directory of the Last Step of the Tutorial
WORKDIR /usr/src/tutorial/pwasm-tutorial/step-5

# Compile the contract
RUN ./build.sh

#---------------------------------------------