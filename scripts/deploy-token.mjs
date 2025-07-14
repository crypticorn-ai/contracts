import hre from "hardhat";
import chalk from 'chalk';

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log(chalk.blue.bold("Deploying Crypticorn token with the account:"), chalk.cyan(deployer.address));
  console.log(chalk.blue("Account balance:"), chalk.yellow((await deployer.provider.getBalance(deployer.address)).toString()));

  // Get deployment parameters from environment or use defaults
  const marketingWallet = process.env.MARKETING_WALLET || deployer.address;
  const tokenName = process.env.TOKEN_NAME || "Crypticorn";
  const tokenSymbol = process.env.TOKEN_SYMBOL || "CRYPTO";

  console.log(chalk.blue("Marketing wallet:"), chalk.cyan(marketingWallet));
  console.log(chalk.blue("Token name:"), chalk.cyan(tokenName));
  console.log(chalk.blue("Token symbol:"), chalk.cyan(tokenSymbol));

  // Deploy Crypticorn Token
  const Crypticorn = await hre.ethers.getContractFactory("Crypticorn");
  const tokenContract = await Crypticorn.deploy(marketingWallet, tokenName, tokenSymbol);
  
  await tokenContract.waitForDeployment();
  const tokenAddress = await tokenContract.getAddress();
  
  console.log(chalk.green.bold("Crypticorn token deployed to:"), chalk.cyan(tokenAddress));

  // Wait for a few block confirmations before verification
  console.log(chalk.blue("Waiting for block confirmations..."));
  await tokenContract.deploymentTransaction().wait(5);

  // Verify the contract on BSCScan
  try {
    console.log(chalk.blue("Verifying contract on BSCScan..."));
    await hre.run("verify:verify", {
      address: tokenAddress,
      constructorArguments: [marketingWallet, tokenName, tokenSymbol],
    });
    console.log(chalk.green.bold("Contract verified successfully!"));
  } catch (error) {
    console.log(chalk.red.bold("Verification failed:"), error.message);
  }

  // Log deployment summary
  console.log(chalk.magenta.bold("\n=== Deployment Summary ==="));
  console.log(chalk.blue("Contract:"), chalk.cyan("Crypticorn Token"));
  console.log(chalk.blue("Address:"), chalk.cyan(tokenAddress));
  console.log(chalk.blue("Marketing Wallet:"), chalk.cyan(marketingWallet));
  console.log(chalk.blue("Name:"), chalk.cyan(tokenName));
  console.log(chalk.blue("Symbol:"), chalk.cyan(tokenSymbol));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
  console.log(chalk.blue("Deployer:"), chalk.cyan(deployer.address));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 