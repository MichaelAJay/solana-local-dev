#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/wallet-utils.sh"
source "$SCRIPT_DIR/token-utils.sh"

# Function to check account details
checkAcct() {
    local wallet_type=$1
    
    # Check if local validator is running
    if ! check_local_validator; then
        return 1
    fi
    
    # Validate input
    if [[ "$wallet_type" != "ops" && "$wallet_type" != "hot" && "$wallet_type" != "owner" ]]; then
        echo "❌ Invalid wallet type. Use 'ops', 'hot', or 'owner'"
        echo "Usage: checkAcct <wallet_type>"
        echo "Example: checkAcct ops"
        return 1
    fi
    
    # Get wallet address
    local wallet_address=$(get_wallet_address "$wallet_type")
    if [[ -z "$wallet_address" ]]; then
        echo "❌ Wallet file ${wallet_type}.json not found"
        echo "💡 Run the initialization script first to create wallets"
        return 1
    fi
    
    echo ""
    echo "🔍 Account Details for $wallet_type wallet"
    echo "========================================="
    echo "📍 Public Key: $wallet_address"
    
    # Get SOL balance
    local sol_balance=$(solana balance "$wallet_address" 2>/dev/null | awk '{print $1}')
    if [[ -n "$sol_balance" ]]; then
        echo "💰 SOL Balance: $sol_balance SOL"
    else
        echo "💰 SOL Balance: 0 SOL"
    fi
    
    # Get token balances
    echo ""
    echo "🪙 Token Balances:"
    echo "=================="
    
    # Check for USDC tokens
    local usdc_mint=$(get_token_mint "USDC" 2>/dev/null)
    if [[ -n "$usdc_mint" ]]; then
        local usdc_balance=$(get_token_balance "$wallet_address" "$usdc_mint")
        echo "  - USDC: $usdc_balance"
        
        # Show ATA address if it exists
        if ata_exists "$wallet_address" "$usdc_mint"; then
            local ata_address=$(get_ata_address "$wallet_address" "$usdc_mint")
            echo "    📍 ATA Address: $ata_address"
        else
            echo "    ⚠️  No ATA found for USDC"
        fi
    else
        echo "  - USDC: No mint found"
    fi
    
    # List all token accounts for this wallet
    echo ""
    echo "🏦 Associated Token Accounts:"
    echo "============================="
    
    local token_accounts=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA accounts --owner "$wallet_address" 2>/dev/null)
    if [[ -n "$token_accounts" ]]; then
        echo "$token_accounts"
    else
        echo "No token accounts found"
    fi
    
    echo ""
    echo "✅ Account check complete for $wallet_type wallet"
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "❌ Missing wallet type parameter"
        echo "Usage: $0 <wallet_type>"
        echo "Example: $0 ops"
        exit 1
    fi
    
    checkAcct "$1"
fi 