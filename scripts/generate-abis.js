import fs from 'fs';
import path from 'path';
import chalk from 'chalk';

async function generateABIs() {
  const artifactsDir = path.join(process.cwd(), 'artifacts', 'contracts');
  const outputDir = path.join(process.cwd(), 'artifacts', 'generated-src');

  // Create output directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Function to recursively find all .json files in artifacts/contracts
  function findContractFiles(dir) {
    const files = [];
    const items = fs.readdirSync(dir);
    
    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory()) {
        files.push(...findContractFiles(fullPath));
      } else if (item.endsWith('.json') && !item.endsWith('.dbg.json')) {
        files.push(fullPath);
      }
    }
    
    return files;
  }

  try {
    const contractFiles = findContractFiles(artifactsDir);
    
    for (const filePath of contractFiles) {
      try {
        const content = fs.readFileSync(filePath, 'utf8');
        const artifact = JSON.parse(content);
        
        if (artifact.abi && Array.isArray(artifact.abi)) {
          const contractName = artifact.contractName;
          const outputPath = path.join(outputDir, `${contractName}.ts`);
          
          // Format ABI as TypeScript with proper indentation
          const abiString = JSON.stringify(artifact.abi, null, 2);
          
          const tsContent = `export default ${abiString} as const;\n`;
          
          fs.writeFileSync(outputPath, tsContent, 'utf8');
          console.log(chalk.green('Generated ABI TypeScript file:'), chalk.cyan(`${contractName}.ts`));
        }
      } catch (error) {
        console.error(chalk.red('Error processing'), chalk.yellow(filePath + ':'), error.message);
      }
    }
    
    console.log(chalk.green.bold('ABI generation complete!'));
  } catch (error) {
    console.error(chalk.red.bold('Error during ABI generation:'), error.message);
    process.exit(1);
  }
}

generateABIs(); 