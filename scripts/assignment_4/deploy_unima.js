// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

// Node.js File System module.
const fs = require('fs');
const path = require('path');

// Helper function to deploy contracts.
// Notice the use of the spread operator.
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Spread_syntax
const _deploy = async (signer, cName, what="contract", ...args) =>  {
    const Contract = await hre.ethers.getContractFactory(cName, {
        signer: signer,
    });
    const c = await Contract.deploy(...args);
    console.log(`Deploying ${what}...`);
    await c.deployed();
    console.log(`Deployed ${what} to ${c.address}`);
    return c.address;
}

const _saveAddresses = (addresses) => {
    fs.writeFileSync(path.join(__dirname, ".addresses.json"),
                     JSON.stringify(addresses));
    console.log("Deployed addresses saved to .addresses.json")
};

async function main() {

    // 0. Getting signers added in hardhat.config.js
    // Pick the deployer (default is signer1).
    const [signer1, signer2] = await hre.ethers.getSigners();
    const signer = signer1;
    console.log("Signer address: " + signer.address);

    // On-chain validator:
    const validatorAddress = '0xaBfE6D21E69eEe5eB228E007c23eeF45c5BB539e';
    
    // On-chain validator:
    const registryAddress = '0xCd7368D363d30469bf70A7135578716988FC1BdD';

    // 3. Deploying ERC20 token.
    const tokenAddress = await _deploy(
                                      // Parameters for fetching contract.
                                      signer, "Assignment4Coin", "Token",
                                      // Parameters for ERC20's constructor.
                                      "Cool Coin", "CC", 1000);
   
    // 4. Finally, deploying the AMM.
    const ammAddress = await _deploy(
                                    // Parameters for fetching contract.
                                    signer, "Assignment4Exchange", "AMM",
                                    // Parameters for AMM's constructor.
                                    tokenAddress, 
                                    validatorAddress, 
                                    registryAddress);

    // Save the addresses so that we can re-use them in the interact.js script.
    // Order matters.
    _saveAddresses([ ammAddress, tokenAddress, registryAddress ]);
                
}




// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
