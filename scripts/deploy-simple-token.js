const hre = require("hardhat");
const chalk = require('chalk');

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log(chalk.magenta.bold("=== Deploying Simplified Crypticorn Token ==="));
  console.log(chalk.blue("Deploying with account:"), chalk.cyan(deployer.address));
  console.log(chalk.blue("Account balance:"), chalk.yellow((await deployer.provider.getBalance(deployer.address)).toString()));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));

  // Get deployment parameters from environment or use defaults
  const marketingWallet = process.env.MARKETING_WALLET || deployer.address;
  const tokenName = process.env.TOKEN_NAME || "Crypticorn";
  const tokenSymbol = process.env.TOKEN_SYMBOL || "CRYPTO";

  console.log(chalk.blue("Marketing wallet:"), chalk.cyan(marketingWallet));
  console.log(chalk.blue("Token name:"), chalk.cyan(tokenName));
  console.log(chalk.blue("Token symbol:"), chalk.cyan(tokenSymbol));

  // Deploy CrypticornSimple Token
  const CrypticornSimple = await hre.ethers.getContractFactory("CrypticornSimple");
  const tokenContract = await CrypticornSimple.deploy(marketingWallet, tokenName, tokenSymbol);
  
  await tokenContract.waitForDeployment();
  const tokenAddress = await tokenContract.getAddress();
  
  console.log(chalk.green.bold("SUCCESS: CrypticornSimple deployed to:"), chalk.cyan(tokenAddress));

  // Wait for block confirmations before verification
  console.log(chalk.blue("Waiting for block confirmations..."));
  await tokenContract.deploymentTransaction().wait(5);

  // Verify the contract on BSCScan
  try {
    console.log(chalk.blue("Verifying contract on BSCScan..."));
    await hre.run("verify:verify", {
      address: tokenAddress,
      constructorArguments: [marketingWallet, tokenName, tokenSymbol],
    });
    console.log(chalk.green.bold("SUCCESS: Contract verified successfully!"));
  } catch (error) {
    console.log(chalk.red.bold("FAILED: Verification failed:"), error.message);
  }

  // Log deployment summary
  console.log(chalk.magenta.bold("\n=== Deployment Summary ==="));
  console.log(chalk.blue("Contract:"), chalk.cyan("CrypticornSimple"));
  console.log(chalk.blue("Address:"), chalk.cyan(tokenAddress));
  console.log(chalk.blue("Name:"), chalk.cyan(tokenName));
  console.log(chalk.blue("Symbol:"), chalk.cyan(tokenSymbol));
  console.log(chalk.blue("Total Supply:"), chalk.cyan("100,000,000 tokens"));
  console.log(chalk.blue("Marketing Wallet:"), chalk.cyan(marketingWallet));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
  console.log(chalk.blue("Deployer:"), chalk.cyan(deployer.address));
  
  console.log(chalk.yellow.bold("\n=== Next Steps ==="));
  console.log(chalk.blue("1. Enable trading:"), chalk.cyan(`contract.enableTrading()`));
  console.log(chalk.blue("2. Set up liquidity on PancakeSwap manually"));
  console.log(chalk.blue("3. Deploy staking contract with this token address"));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 