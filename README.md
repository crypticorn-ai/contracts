# Crypticorn Smart Contracts

Smart contracts for the Crypticorn ecosystem including the BEP20 token and staking platform.

## Contracts

### Crypticorn Token (`contracts/Crypticorn.sol`)
- BEP20 token with advanced features
- Automatic liquidity provision
- Marketing wallet integration
- Tax system for buys/sells

### CrypticornStaking (`contracts/CrypticornStaking.sol`) 
- Multi-pool staking system for Crypticorn tokens
- 3 different staking pools with varying lock periods and APY rates
- Pool 1: No lock period, 2% APY
- Pool 2: 90-day lock, 10% APY  
- Pool 3: 180-day lock, 15% APY
- Owner fee withdrawal capabilities
- Automatic reward calculation and claiming

## Features

- BSC deployment ready with verification
- **Automatic TypeScript ABI generation**
- Comprehensive deployment scripts
- Multi-contract deployment support

## Setup

1. Install dependencies:
```bash
pnpm install
```

2. Copy environment file and configure:
```bash
cp env.example .env
```

3. Fill in your `.env` file:
```bash
PRIVATE_KEY=your_wallet_private_key_without_0x
BSCSCAN_API_KEY=your_bscscan_api_key

# For token deployment
MARKETING_WALLET=your_marketing_wallet_address
TOKEN_NAME=Crypticorn
TOKEN_SYMBOL=CRYPTO

# For staking-only deployment with existing token
TOKEN_ADDRESS=your_existing_token_contract_address
```

## Deployment Options

### Full Ecosystem (Token + Staking)
```bash
# Deploy both contracts in sequence
pnpm deploy:testnet     # or deploy:mainnet
```

### Individual Contract Deployment

#### Token Only
```bash
pnpm deploy:token:testnet     # or deploy:token:mainnet
```

#### Staking Only (requires existing token)
```bash
pnpm deploy:staking:testnet   # or deploy:staking:mainnet
```

## Verification

All deployment scripts automatically verify contracts on BSCScan. For manual verification:

```bash
# Token contract
npx hardhat verify --network bscMainnet TOKEN_ADDRESS "MARKETING_WALLET" "TOKEN_NAME" "TOKEN_SYMBOL"

# Staking contract  
npx hardhat verify --network bscMainnet STAKING_ADDRESS TOKEN_ADDRESS
```

## Build Artifacts

After compilation, build artifacts are located in:
- `artifacts/contracts/Crypticorn.sol/Crypticorn.json` - Token contract ABI and bytecode
- `artifacts/contracts/CrypticornStaking.sol/CrypticornStaking.json` - Staking contract ABI and bytecode
- `artifacts/generated-src/Crypticorn.ts` - **Token TypeScript ABI export (auto-generated)**
- `artifacts/generated-src/CrypticornStaking.ts` - **Staking TypeScript ABI export (auto-generated)**

The TypeScript ABI files export contract ABIs as const and can be imported directly:
```typescript
import CrypticornABI from './artifacts/generated-src/Crypticorn';
import CrypticornStakingABI from './artifacts/generated-src/CrypticornStaking';
// Both ABIs contain full ABI with TypeScript type safety
```

## Commands

- `pnpm compile` - Compile contracts and generate TypeScript ABIs
- `pnpm generate-abis` - Generate TypeScript ABI files from compiled artifacts
- `pnpm deploy:testnet` - Deploy full ecosystem to BSC Testnet
- `pnpm deploy:mainnet` - Deploy full ecosystem to BSC Mainnet
- `pnpm deploy:token:testnet` - Deploy only token to BSC Testnet
- `pnpm deploy:token:mainnet` - Deploy only token to BSC Mainnet
- `pnpm deploy:staking:testnet` - Deploy only staking to BSC Testnet
- `pnpm deploy:staking:mainnet` - Deploy only staking to BSC Mainnet
- `pnpm test` - Run tests

To best take advantage of shell completions, install the Fish shell and type:
```
npm run [TAB]
```

## Network Configuration

### BSC Mainnet
- RPC: https://bsc-dataseed1.binance.org
- Chain ID: 56
- Explorer: https://bscscan.com

### BSC Testnet
- RPC: https://data-seed-prebsc-1-s1.binance.org:8545
- Chain ID: 97
- Explorer: https://testnet.bscscan.com

## Security Notes

- Never commit your `.env` file
- Keep your private key secure
- Test on testnet before mainnet deployment
- Verify contract source code on BSCScan after deployment 