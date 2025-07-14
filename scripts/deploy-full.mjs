import hre from "hardhat";
import chalk from 'chalk';

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log(chalk.magenta.bold("=== Full Crypticorn Deployment ==="));
  console.log(chalk.blue("Deploying with account:"), chalk.cyan(deployer.address));
  console.log(chalk.blue("Account balance:"), chalk.yellow((await deployer.provider.getBalance(deployer.address)).toString()));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));

  // Get deployment parameters from environment or use defaults
  const marketingWallet = process.env.MARKETING_WALLET || deployer.address;
  const tokenName = process.env.TOKEN_NAME || "Crypticorn";
  const tokenSymbol = process.env.TOKEN_SYMBOL || "CRYPTO";

  console.log(chalk.yellow.bold("\n=== Step 1: Deploy Crypticorn Token ==="));
  console.log(chalk.blue("Marketing wallet:"), chalk.cyan(marketingWallet));
  console.log(chalk.blue("Token name:"), chalk.cyan(tokenName));
  console.log(chalk.blue("Token symbol:"), chalk.cyan(tokenSymbol));

  // Deploy Crypticorn Token
  const Crypticorn = await hre.ethers.getContractFactory("Crypticorn");
  const tokenContract = await Crypticorn.deploy(marketingWallet, tokenName, tokenSymbol);
  
  await tokenContract.waitForDeployment();
  const tokenAddress = await tokenContract.getAddress();
  
  console.log(chalk.green.bold("SUCCESS: Crypticorn token deployed to:"), chalk.cyan(tokenAddress));

  console.log(chalk.yellow.bold("\n=== Step 2: Deploy Staking Contract ==="));
  
  // Deploy CrypticornStaking with the deployed token
  const CrypticornStaking = await hre.ethers.getContractFactory("CrypticornStaking");
  const stakingContract = await CrypticornStaking.deploy(tokenAddress);
  
  await stakingContract.waitForDeployment();
  const stakingAddress = await stakingContract.getAddress();
  
  console.log(chalk.green.bold("SUCCESS: CrypticornStaking deployed to:"), chalk.cyan(stakingAddress));

  // Wait for block confirmations before verification
  console.log(chalk.yellow.bold("\n=== Step 3: Contract Verification ==="));
  console.log(chalk.blue("Waiting for block confirmations..."));
  await tokenContract.deploymentTransaction().wait(5);
  await stakingContract.deploymentTransaction().wait(5);

  // Verify the token contract
  try {
    console.log(chalk.blue("Verifying Crypticorn token on BSCScan..."));
    await hre.run("verify:verify", {
      address: tokenAddress,
      constructorArguments: [marketingWallet, tokenName, tokenSymbol],
    });
    console.log(chalk.green.bold("SUCCESS: Token contract verified successfully!"));
  } catch (error) {
    console.log(chalk.red.bold("FAILED: Token verification failed:"), error.message);
  }

  // Verify the staking contract
  try {
    console.log(chalk.blue("Verifying CrypticornStaking on BSCScan..."));
    await hre.run("verify:verify", {
      address: stakingAddress,
      constructorArguments: [tokenAddress],
    });
    console.log(chalk.green.bold("SUCCESS: Staking contract verified successfully!"));
  } catch (error) {
    console.log(chalk.red.bold("FAILED: Staking verification failed:"), error.message);
  }

  // Final deployment summary
  console.log(chalk.magenta.bold("\n=== Final Deployment Summary ==="));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
  console.log(chalk.blue("Deployer:"), chalk.cyan(deployer.address));
  console.log("");
  console.log(chalk.blue("Crypticorn Token:"));
  console.log(chalk.blue("  Address:"), chalk.cyan(tokenAddress));
  console.log(chalk.blue("  Name:"), chalk.cyan(tokenName));
  console.log(chalk.blue("  Symbol:"), chalk.cyan(tokenSymbol));
  console.log(chalk.blue("  Marketing Wallet:"), chalk.cyan(marketingWallet));
  console.log("");
  console.log(chalk.blue("CrypticornStaking:"));
  console.log(chalk.blue("  Address:"), chalk.cyan(stakingAddress));
  console.log(chalk.blue("  Token:"), chalk.cyan(tokenAddress));
  console.log("");
  console.log(chalk.green.bold("COMPLETE: Full deployment finished successfully!"));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 