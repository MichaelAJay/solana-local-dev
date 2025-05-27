#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/wallet-utils.sh"
source "$SCRIPT_DIR/token-utils.sh"

# Function to mint tokens
mint_tokens() {
    local amount=$1
    local token_name=${2:-"USDC"}  # Default to USDC if not specified
    
    # Check if local validator is running
    if ! check_local_validator; then
        return 1
    fi
    
    # Validate inputs
    if [[ -z "$amount" ]]; then
        echo "❌ Missing required parameter: amount"
        echo "Usage: mint-tokens <amount> [token_name]"
        echo "Example: mint-tokens 1000"
        echo "Example: mint-tokens 1000 USDC"
        return 1
    fi
    
    # Validate amount is a positive number
    if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$amount <= 0" | bc -l) )); then
        echo "❌ Invalid amount: $amount"
        echo "Amount must be a positive number"
        echo "Example: mint-tokens 1000"
        return 1
    fi
    
    # Get owner wallet address (mint authority)
    local owner_address=$(get_wallet_address "owner")
    if [[ -z "$owner_address" ]]; then
        echo "❌ Owner wallet file (owner.json) not found"
        echo "💡 Run the initialization script first to create wallets"
        return 1
    fi
    
    # Get token mint address
    local mint_address=$(get_token_mint "$token_name")
    if [[ -z "$mint_address" ]]; then
        echo "❌ Token mint not found for $token_name"
        echo "💡 Run the initialization script first to create tokens"
        echo "💡 Or check if ${token_name}_mint.txt exists"
        return 1
    fi
    
    echo ""
    echo "🪙 Minting Tokens"
    echo "================="
    echo "🏷️  Token: $token_name"
    echo "📍 Mint address: $mint_address"
    echo "🔑 Mint authority: owner ($owner_address)"
    echo "💵 Amount to mint: $amount"
    echo "📦 Recipient: owner wallet"
    
    # Check if owner has an ATA for this token
    if ! ata_exists "$owner_address" "$mint_address"; then
        echo ""
        echo "🏦 Creating Associated Token Account for owner..."
        if ! createAta "$owner_address" "$mint_address" "owner"; then
            echo "❌ Failed to create ATA for owner wallet"
            return 1
        fi
    fi
    
    # Get owner's ATA address
    local owner_ata=$(get_ata_address "$owner_address" "$mint_address")
    if [[ -z "$owner_ata" ]]; then
        echo "❌ Could not get ATA address for owner wallet"
        return 1
    fi
    
    echo "🏦 Owner ATA: $owner_ata"
    
    # Get current token balance
    local current_balance=$(get_token_balance "$owner_address" "$mint_address")
    echo "💰 Current balance: $current_balance $token_name"
    
    # Store current keypair and switch to owner
    local current_keypair=$(solana config get | grep "Keypair Path" | awk '{print $3}')
    solana config set --keypair "owner.json" >/dev/null 2>&1
    
    # Perform the mint operation
    echo ""
    echo "⚡ Minting tokens..."
    local mint_result=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA mint "$mint_address" "$amount" "$owner_ata" 2>&1)
    local mint_exit_code=$?
    
    # Restore original keypair
    solana config set --keypair "$current_keypair" >/dev/null 2>&1
    
    if [[ $mint_exit_code -eq 0 ]]; then
        echo "✅ Mint successful!"
        
        # Get signature from result
        local signature=$(echo "$mint_result" | grep -o '[A-Za-z0-9]\{87,88\}')
        if [[ -n "$signature" ]]; then
            echo "📝 Transaction signature: $signature"
        fi
        
        # Wait a moment for balance to update
        sleep 2
        
        # Get new balance
        local new_balance=$(get_token_balance "$owner_address" "$mint_address")
        echo "💰 New balance: $new_balance $token_name"
        
        # Calculate the actual amount minted
        if [[ "$current_balance" != "0" && "$new_balance" != "0" ]]; then
            local minted=$(echo "$new_balance - $current_balance" | bc -l)
            echo "📈 Amount minted: $minted $token_name"
        fi
        
        echo ""
        echo "✅ Mint operation complete!"
        return 0
    else
        echo "❌ Mint failed!"
        echo "Error: $mint_result"
        
        # Provide helpful error messages
        if [[ "$mint_result" == *"insufficient funds"* ]]; then
            echo ""
            echo "💡 Insufficient SOL for transaction fees. Try airdropping some SOL to the owner wallet."
        elif [[ "$mint_result" == *"mint authority"* ]]; then
            echo ""
            echo "💡 Owner wallet is not the mint authority for this token."
        elif [[ "$mint_result" == *"Account not found"* ]]; then
            echo ""
            echo "💡 Token mint or ATA not found. Run initialization script first."
        fi
        
        return 1
    fi
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "❌ Missing required parameter: amount"
        echo "Usage: $0 <amount> [token_name]"
        echo "Example: $0 1000"
        echo "Example: $0 1000 USDC"
        exit 1
    fi
    
    mint_tokens "$1" "$2"
fi 