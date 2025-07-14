import hre from "hardhat";
import chalk from 'chalk';

async function main() {
  try {
    const [deployer] = await hre.ethers.getSigners();
    
    console.log(chalk.magenta.bold("=== Deployment Cost Estimation ==="));
    console.log(chalk.blue("Network:"), chalk.cyan(hre.network.name));
    console.log(chalk.blue("Deployer Address:"), chalk.cyan(deployer.address));
    
    // Check current balance
    const balance = await deployer.provider.getBalance(deployer.address);
    const balanceInBNB = hre.ethers.formatEther(balance);
    console.log(chalk.blue("Current Balance:"), chalk.yellow(`${balanceInBNB} BNB`));
    
    // Get current gas price
    const feeData = await deployer.provider.getFeeData();
    const gasPrice = feeData.gasPrice;
    console.log(chalk.blue("Current Gas Price:"), chalk.yellow(`${hre.ethers.formatUnits(gasPrice, 'gwei')} gwei`));
    
    // Get deployment parameters
    const marketingWallet = process.env.MARKETING_WALLET || deployer.address;
    const tokenName = process.env.TOKEN_NAME || "Crypticorn";
    const tokenSymbol = process.env.TOKEN_SYMBOL || "CRYPTO";
    
    console.log(chalk.yellow.bold("\n=== Gas Estimation ==="));
    
    // Estimate Crypticorn token deployment
    const CrypticornFactory = await hre.ethers.getContractFactory("Crypticorn");
    const tokenDeployTx = await CrypticornFactory.getDeployTransaction(marketingWallet, tokenName, tokenSymbol);
    const tokenGasEstimate = await deployer.estimateGas(tokenDeployTx);
    
    console.log(chalk.blue("Crypticorn Token:"));
    console.log(chalk.blue("  Estimated Gas:"), chalk.cyan(tokenGasEstimate.toString()));
    
    // Estimate Staking contract deployment
    const StakingFactory = await hre.ethers.getContractFactory("CrypticornStaking");
    const stakingDeployTx = await StakingFactory.getDeployTransaction("0x0000000000000000000000000000000000000001");
    const stakingGasEstimate = await deployer.estimateGas(stakingDeployTx);
    
    console.log(chalk.blue("CrypticornStaking:"));
    console.log(chalk.blue("  Estimated Gas:"), chalk.cyan(stakingGasEstimate.toString()));
    
    // Calculate costs
    const totalGas = tokenGasEstimate + stakingGasEstimate;
    const tokenCost = tokenGasEstimate * gasPrice;
    const stakingCost = stakingGasEstimate * gasPrice;
    const totalCost = totalGas * gasPrice;
    
    console.log(chalk.yellow.bold("\n=== Cost Breakdown ==="));
    console.log(chalk.blue("Crypticorn Token:"));
    console.log(chalk.blue("  Gas:"), chalk.cyan(tokenGasEstimate.toString()));
    console.log(chalk.blue("  Cost:"), chalk.yellow(`${hre.ethers.formatEther(tokenCost)} BNB`));
    console.log(chalk.blue("  USD (est.):"), chalk.yellow(`$${(parseFloat(hre.ethers.formatEther(tokenCost)) * 700).toFixed(2)}`)); // Assuming ~$700/BNB
    
    console.log(chalk.blue("\nCrypticornStaking:"));
    console.log(chalk.blue("  Gas:"), chalk.cyan(stakingGasEstimate.toString()));
    console.log(chalk.blue("  Cost:"), chalk.yellow(`${hre.ethers.formatEther(stakingCost)} BNB`));
    console.log(chalk.blue("  USD (est.):"), chalk.yellow(`$${(parseFloat(hre.ethers.formatEther(stakingCost)) * 700).toFixed(2)}`));
    
    console.log(chalk.green.bold("\nTOTAL DEPLOYMENT COST:"));
    console.log(chalk.green("  Total Gas:"), chalk.cyan(totalGas.toString()));
    console.log(chalk.green("  Total Cost:"), chalk.yellow(`${hre.ethers.formatEther(totalCost)} BNB`));
    console.log(chalk.green("  USD (est.):"), chalk.yellow(`$${(parseFloat(hre.ethers.formatEther(totalCost)) * 700).toFixed(2)}`));
    
    // Safety checks
    console.log(chalk.yellow.bold("\n=== Balance Safety Check ==="));
    const costWithBuffer = totalCost * 120n / 100n; // 20% buffer
    
    if (balance >= costWithBuffer) {
      console.log(chalk.green.bold("SUFFICIENT FUNDS: You have enough BNB for deployment (with 20% buffer)"));
    } else if (balance >= totalCost) {
      console.log(chalk.yellow.bold("TIGHT BUDGET: You have enough BNB but with minimal buffer"));
    } else {
      console.log(chalk.red.bold("INSUFFICIENT FUNDS: You need more BNB for deployment"));
      const needed = costWithBuffer - balance;
      console.log(chalk.red("   Additional needed:"), chalk.yellow(`${hre.ethers.formatEther(needed)} BNB`));
    }
    
    console.log(chalk.blue("\nRecommended Balance:"), chalk.yellow(`${hre.ethers.formatEther(costWithBuffer)} BNB (with 20% buffer)`));
  } catch (error) {
    console.error(chalk.red.bold("Error estimating costs:"), error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(chalk.red.bold(error));
    process.exit(1);
  }); 