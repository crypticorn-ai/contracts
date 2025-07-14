import hre from "hardhat";
import chalk from 'chalk';

async function main() {
  try {
    const [deployer] = await hre.ethers.getSigners();
    
    console.log(chalk.magenta.bold("=== Wallet Safety Check ==="));
    console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
    console.log(chalk.blue("Deployer Address:"), chalk.cyan(deployer.address));
    
    // Check balance
    const balance = await deployer.provider.getBalance(deployer.address);
    const balanceInBNB = hre.ethers.formatEther(balance);
    
    console.log(chalk.blue("Balance:"), chalk.yellow(`${balanceInBNB} BNB`));
    
    // Estimate deployment cost
    const gasPrice = await deployer.provider.getFeeData();
    console.log(chalk.blue("Current Gas Price:"), chalk.yellow(`${hre.ethers.formatUnits(gasPrice.gasPrice, 'gwei')} gwei`));
    
    // Rough estimate: staking contract deployment ~2-3M gas
    const estimatedGasUsed = 2500000n; // 2.5M gas estimate
    const estimatedCost = estimatedGasUsed * gasPrice.gasPrice;
    const estimatedCostBNB = hre.ethers.formatEther(estimatedCost);
    
    console.log(chalk.blue("Estimated Deployment Cost:"), chalk.yellow(`~${estimatedCostBNB} BNB`));
    
    // Safety checks
    const minimumBalance = hre.ethers.parseEther("0.01"); // 0.01 BNB minimum
    if (balance < minimumBalance) {
      console.log(chalk.red.bold("WARNING: Low balance! You may not have enough BNB for deployment."));
    } else {
      console.log(chalk.green.bold("Balance looks sufficient for deployment."));
    }
  } catch (error) {
    console.error(chalk.red.bold("Error checking wallet:"), error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 