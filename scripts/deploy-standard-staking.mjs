import hre from "hardhat";
import chalk from 'chalk';

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log(chalk.blue.bold("Deploying contracts with the account:"), chalk.cyan(deployer.address));
  console.log(chalk.blue("Account balance:"), chalk.yellow((await deployer.provider.getBalance(deployer.address)).toString()));

  // Get constructor arguments from environment variables
  const tokenAddress = process.env.TOKEN_ADDRESS;
  const initialApyBps = process.env.INITIAL_APY_BPS; // APY in basis points, e.g., 500 = 5%

  if (!tokenAddress) {
    throw new Error("TOKEN_ADDRESS environment variable is required");
  }
  if (!initialApyBps) {
    throw new Error("INITIAL_APY_BPS environment variable is required");
  }

  const initialApy = parseInt(initialApyBps, 10);
  if (isNaN(initialApy) || initialApy < 0) {
    throw new Error("INITIAL_APY_BPS must be a positive integer");
  }

  console.log(chalk.blue("Token address:"), chalk.cyan(tokenAddress));
  console.log(chalk.blue("Initial APY (bps):"), chalk.cyan(initialApy));

  // Deploy CrypticornStandardStaking
  const StandardStaking = await hre.ethers.getContractFactory("CrypticornStandardStaking");
  const stakingContract = await StandardStaking.deploy(tokenAddress, initialApy);

  await stakingContract.waitForDeployment();
  const contractAddress = await stakingContract.getAddress();

  console.log(chalk.green.bold("CrypticornStandardStaking deployed to:"), chalk.cyan(contractAddress));

  // Wait for a few block confirmations before verification
  console.log(chalk.blue("Waiting for block confirmations..."));
  await stakingContract.deploymentTransaction().wait(12);

  // Verify the contract on BSCScan (or Etherscan depending on network)
  try {
    console.log(chalk.blue("Verifying contract on BSCScan..."));
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [tokenAddress, initialApy],
    });
    console.log(chalk.green.bold("Contract verified successfully!"));
  } catch (error) {
    console.log(chalk.red.bold("Verification failed:"), error.message);
  }

  // Log deployment summary
  console.log(chalk.magenta.bold("\n=== Deployment Summary ==="));
  console.log(chalk.blue("Contract:"), chalk.cyan("CrypticornStandardStaking"));
  console.log(chalk.blue("Address:"), chalk.cyan(contractAddress));
  console.log(chalk.blue("Token:"), chalk.cyan(tokenAddress));
  console.log(chalk.blue("Initial APY (bps):"), chalk.cyan(initialApy));
  console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
  console.log(chalk.blue("Deployer:"), chalk.cyan(deployer.address));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 