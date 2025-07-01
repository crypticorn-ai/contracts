import hre from "hardhat";
import chalk from 'chalk';

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log(chalk.blue.bold("Deploying contracts with the account:"), chalk.cyan(deployer.address));
  console.log(chalk.blue("Account balance:"), chalk.yellow((await deployer.provider.getBalance(deployer.address)).toString()));

  // Get the token address from environment or prompt
  const tokenAddress = process.env.TOKEN_ADDRESS;
  if (!tokenAddress) {
    throw new Error("TOKEN_ADDRESS environment variable is required");
  }

  console.log(chalk.blue("Token address:"), chalk.cyan(tokenAddress));

  // Deploy CrypticornStaking
  const CrypticornStaking = await hre.ethers.getContractFactory("CrypticornStaking");
  const stakingContract = await CrypticornStaking.deploy(tokenAddress);
  
  await stakingContract.waitForDeployment();
  const contractAddress = await stakingContract.getAddress();
  
  console.log(chalk.green.bold("CrypticornStaking deployed to:"), chalk.cyan(contractAddress));

  // Wait for a few block confirmations before verification
  console.log(chalk.blue("Waiting for block confirmations..."));
  await stakingContract.deploymentTransaction().wait(5);

  // Verify the contract on BSCScan
  try {
    console.log(chalk.blue("Verifying contract on BSCScan..."));
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [tokenAddress],
    });
    console.log(chalk.green.bold("Contract verified successfully!"));
  } catch (error) {
    console.log(chalk.red.bold("Verification failed:"), error.message);
  }

  // Log deployment summary
  console.log(chalk.magenta.bold("\n=== Deployment Summary ==="));
  console.log(chalk.blue("Contract:"), chalk.cyan("CrypticornStaking"));
  console.log(chalk.blue("Address:"), chalk.cyan(contractAddress));
  console.log(chalk.blue("Token:"), chalk.cyan(tokenAddress));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
  console.log(chalk.blue("Deployer:"), chalk.cyan(deployer.address));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 