# Solana Local Development Utilities

A collection of shell scripts to easily set up and manage a local Solana development environment with wallets, tokens, and Associated Token Accounts (ATAs).

## 🚀 Quick Start

1. **Start the local Solana test validator:**
   ```bash
   solana-test-validator
   ```

2. **Initialize your local node:**
   ```bash
   ./solana-local init
   ```

3. **Check wallet details:**
   ```bash
   ./solana-local check owner
   ./solana-local check ops
   ./solana-local check hot
   ```

## 🛠 Commands

### Main Wrapper Script

The `solana-local` script provides a unified interface to all functionality:

```bash
./solana-local <command> [arguments]
```

#### Available Commands:

- **`init`** - Initialize local Solana node with wallets and tokens
- **`check <wallet_type>`** - Check account details (ops, hot, or owner)
- **`wallet-info <wallet_type>`** - Get wallet info as JSON (ops or hot only)
- **`airdrop <amount> <wallet_type>`** - Airdrop SOL to a wallet
- **`mint <amount> [token_name]`** - Mint tokens to owner wallet (default: USDC)
- **`send-sol --amount <amount> --from <wallet> --to <wallet>`** - Send SOL between wallets
- **`send-token --amount <amount> --from <wallet> --to <wallet>`** - Send tokens between wallets
- **`validator`** - Check if local validator is running

#### Examples:

```bash
# Initialize everything
./solana-local init

# Check specific wallets
./solana-local check owner
./solana-local check ops
./solana-local check hot

# Get wallet info as JSON (for ops and hot wallets only)
# Note: Will prompt for confirmation due to private key exposure
./solana-local wallet-info ops
./solana-local wallet-info hot

# Airdrop SOL to wallets
./solana-local airdrop 5 ops
./solana-local airdrop 2.5 hot
./solana-local airdrop 10 owner

# Mint tokens to owner wallet
./solana-local mint 1000
./solana-local mint 500 USDC

# Send SOL between wallets
./solana-local send-sol --amount 1.5 --from owner --to ops
./solana-local send-sol --amount 0.1 --from ops --to hot

# Send tokens between wallets
./solana-local send-token --amount 1000 --from owner --to ops
./solana-local send-token --amount 50.5 --from ops --to hot

# Check validator status
./solana-local validator

# Show help
./solana-local help
```

### Individual Scripts

You can also run the scripts directly:

```bash
# Initialize local node
./scripts/init-local-node.sh

# Check account details
./scripts/check-account.sh ops

# Get wallet info as JSON
./scripts/get-wallet-info.sh ops
./scripts/get-wallet-info.sh hot

# Airdrop SOL to wallets
./scripts/airdrop.sh 5 ops
./scripts/airdrop.sh 2.5 hot
./scripts/airdrop.sh 10 owner

# Mint tokens to owner wallet
./scripts/mint-tokens.sh 1000
./scripts/mint-tokens.sh 500 USDC

# Send SOL between wallets
./scripts/send-sol.sh --amount 1.5 --from owner --to ops
./scripts/send-sol.sh --amount 0.1 --from ops --to hot

# Send tokens between wallets
./scripts/send-token.sh --amount 1000 --from owner --to ops
./scripts/send-token.sh --amount 50.5 --from ops --to hot

# Check validator status
./scripts/check-validator.sh

# Test mint operations
./scripts/test-mint.sh
```

## 🏗 What Gets Created

When you run `./solana-local init`, the following is set up:

### Wallets
- **Owner wallet** (`owner.json`) - Main wallet with mint authority
- **Ops wallet** (`ops.json`) - Operations wallet
- **Hot wallet** (`hot.json`) - Hot wallet for frequent transactions

### Token
- **USDC token mint** with 6 decimals
- **Mint authority** dynamically set to the owner wallet
- **Associated Token Accounts (ATAs)** for each wallet

### Initial Token Distribution
- **Owner**: 1,000,000 USDC
- **Ops**: 500,000 USDC
- **Hot**: 250,000 USDC

### SOL Airdrops
- Each wallet receives 2 SOL for transaction fees

## 🔧 Script Components

### `check-validator.sh`
- Validates local Solana test validator is running
- Checks RPC connectivity
- Provides helpful error messages and setup instructions

### `wallet-utils.sh`
- Creates or recovers wallet keypairs
- Manages wallet addresses
- Handles SOL airdrops for gas fees
- Robust error handling and validation

### `token-utils.sh`
- Creates token mints with configurable mint authority
- Manages token mint addresses with validation
- Creates Associated Token Accounts (ATAs) with proper keypair switching
- Mints tokens with mint authority validation
- Calculates ATA addresses
- Checks token balances and account existence

### `init-local-node.sh`
- Orchestrates the complete setup process
- Creates all wallets and tokens from scratch
- Validates existing mints and recreates if corrupted
- Sets up ATAs and mints initial tokens
- Provides comprehensive status reporting
- Handles fresh validator instances and missing artifacts

### `check-account.sh`
- Displays wallet information
- Shows SOL and token balances
- Lists Associated Token Accounts
- Provides ATA addresses

### `get-wallet-info.sh`
- Extracts wallet information as JSON format
- Returns address, private key, and public key in easily copyable format
- Supports only 'ops' and 'hot' wallets for security
- **⚠️ DISPLAYS PRIVATE KEYS IN PLAINTEXT** - Use with extreme caution
- Includes confirmation prompt to prevent accidental exposure
- Checks if local validator is running before execution
- Provides on-chain account status as separate console output (not in JSON)
- Guides users to run init if on-chain accounts don't exist
- Useful for integration with other systems or scripts
- JSON format: `{"address": "...", "privKey": "...", "pubKey": "..."}`

### `send-sol.sh` (New!)
- Transfers SOL between wallets with comprehensive validation
- Uses named parameters: `--amount`, `--from`, `--to`
- Validates amount format (positive numbers only)
- Checks sufficient SOL balance before transfer
- Preserves rent-exempt balance (~0.00089 SOL minimum)
- Prevents transfers to the same wallet
- Shows before/after balances and transaction signatures
- Supports all wallet types: owner, ops, hot
- Handles keypair switching automatically
- Provides detailed error messages and recovery suggestions

### `send-token.sh` (New!)
- Transfers tokens between wallets with comprehensive validation
- Uses named parameters: `--amount`, `--from`, `--to`
- Validates amount format (positive numbers only)
- Checks sufficient token balance before transfer
- Automatically creates destination ATA if needed
- Prevents transfers to the same wallet
- Shows before/after token balances and transaction signatures
- Currently supports USDC tokens
- Validates source and destination ATAs exist
- Handles keypair switching automatically
- Provides detailed error messages and recovery suggestions

### `test-mint.sh`
- Validates mint operations and token setup
- Tests wallet file existence and validity
- Verifies mint authority and on-chain state
- Provides diagnostic information for troubleshooting

### `airdrop.sh` (New!)
- Airdrops SOL to any wallet (owner, ops, or hot)
- Validates amount format (positive numbers only)
- Checks local validator is running before operation
- Shows before/after SOL balances and transaction signatures
- Provides helpful error messages for common issues
- Handles airdrop limits and invalid addresses gracefully
- Simple usage: `./scripts/airdrop.sh <amount> <wallet_type>`

### `mint-tokens.sh` (New!)
- Mints tokens to the owner wallet using owner as mint authority
- Validates amount format (positive numbers only)
- Supports any token with existing mint (defaults to USDC)
- Automatically creates ATA for owner if needed
- Shows before/after token balances and transaction signatures
- Handles keypair switching automatically for mint authority
- Provides detailed error messages and recovery suggestions
- Simple usage: `./scripts/mint-tokens.sh <amount> [token_name]`

## ✨ Key Features

### 🔄 Robust Initialization
- **Fresh Start Support**: Works perfectly with new validator instances
- **Missing File Recovery**: Automatically recreates missing or corrupted files
- **Dynamic Mint Authority**: Always sets mint authority to the owner wallet
- **Comprehensive Validation**: Checks on-chain state and recreates if needed

### 🛡️ Error Handling & Recovery
- **Validator Checks**: Ensures local validator is running before operations
- **File Validation**: Checks for required files and recreates if missing
- **On-Chain Validation**: Verifies accounts exist on-chain, not just locally
- **Automatic Recovery**: Recreates corrupted mints and accounts
- **Clear Error Messages**: Helpful feedback when things go wrong
- **Proper Exit Codes**: Scripts return appropriate exit codes for automation

### 🔧 Advanced Token Operations
- **Keypair Context Switching**: Properly switches between wallets for operations
- **ATA Management**: Creates and validates Associated Token Accounts
- **Token Minting**: Mints tokens with proper authority validation
- **Balance Checking**: Accurate token balance reporting

## ⚠️ Prerequisites

- Solana CLI tools installed
- SPL Token CLI installed
- Local Solana test validator running

## 🔍 Troubleshooting

### Validator Not Running
```bash
# Check validator status
./solana-local validator

# Start validator if needed
solana-test-validator
```

### Missing or Corrupted Files
```bash
# The init script automatically handles missing files
./solana-local init

# Or test current state first
./scripts/test-mint.sh
```

### Fresh Validator Instance
```bash
# After restarting validator, simply re-initialize
# This will create everything from scratch
./solana-local init
```

### Permission Issues
```bash
# Make scripts executable
chmod +x solana-local scripts/*.sh
```

### Mint Authority Issues
The scripts automatically set the mint authority to the owner wallet. If you encounter mint authority errors:

```bash
# Delete existing mint file and reinitialize
rm USDC_mint.txt
./solana-local init
```

### Testing and Validation
```bash
# Run comprehensive tests
./scripts/test-mint.sh

# Check specific wallet
./solana-local check owner

# Get wallet info for integration (ops/hot only)
./solana-local wallet-info ops

# Verify mint details
spl-token display $(cat USDC_mint.txt)
```

### Wallet Info Security
The `wallet-info` command only supports 'ops' and 'hot' wallets for security reasons:
- **Owner wallet excluded** - Contains mint authority and should be kept secure
- **JSON output** - Designed for integration with other systems
- **⚠️ PRIVATE KEY EXPOSURE WARNING ⚠️** - This command displays private keys in plaintext
- **Confirmation required** - Script prompts for confirmation before displaying keys
- **Development only** - Not recommended for production environments

**Security Risks:**
- Private keys are displayed in plaintext on your terminal
- Output may be captured in terminal logs, recordings, or screenshots
- Accidental sharing of output could compromise wallet security
- Screen sharing or recording while running this command is dangerous

**State Considerations:**
- Keypair information is always valid regardless of validator state
- On-chain accounts are ephemeral and reset when validator restarts
- **Solana accounts need rent to exist on-chain** (~0.00089 SOL for basic accounts)
- **Token accounts (ATAs) also need rent** (~0.00204 SOL each)
- The script checks SOL balance and provides specific guidance for funding accounts
- You may need to run `./solana-local init` after validator restarts to recreate accounts
- SOL balances and token accounts will be lost on validator restart
- Use `solana airdrop 1 <address>` to fund individual accounts if needed

**Safe Usage Guidelines:**
- Only run in secure, private environments
- Never run while screen sharing or recording
- Be careful when copying/pasting output
- Clear terminal history after use if needed
- Consider the security implications before each use
- Understand that on-chain state is ephemeral in local development

## 📝 Development

To extend or modify the scripts:

1. **Add new utilities** to the appropriate script in `scripts/`
2. **Update the main wrapper** in `solana-local` if needed
3. **Test individual components** by running scripts directly
4. **Update documentation** in this README
5. **Use the test script** to validate changes: `./scripts/test-mint.sh`

The modular structure makes it easy to add new functionality while maintaining clean separation of concerns.

## 🧪 Testing

The project includes comprehensive testing capabilities:

- **`./scripts/test-mint.sh`** - Validates all components are working correctly
- **Individual script testing** - Each script can be run independently
- **Fresh validator testing** - Scripts handle validator restarts gracefully
- **Missing file recovery** - Automatic detection and recreation of missing artifacts

## 🚀 Production Ready

These scripts are designed for robust local development with features that make them suitable for:

- **CI/CD pipelines** - Reliable initialization and error handling
- **Team development** - Consistent environment setup across developers
- **Testing workflows** - Automated setup and teardown of test environments
- **Educational purposes** - Clear, well-documented Solana development patterns