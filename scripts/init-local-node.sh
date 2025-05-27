#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/wallet-utils.sh"
source "$SCRIPT_DIR/token-utils.sh"

# Main function to initialize local Solana node
initializeLocalSolNode() {
    echo "🚀 Initializing Local Solana Node"
    echo "=================================="
    
    # Check if local validator is running
    if ! check_local_validator; then
        return 1
    fi
    
    # Store current directory
    local current_dir=$(pwd)
    
    # Create wallets
    echo ""
    echo "👛 Creating/Loading Wallets"
    echo "==========================="
    
    # Create owner wallet and set as current keypair
    if ! create_or_recover_wallet "owner"; then
        echo "❌ Failed to create owner wallet"
        return 1
    fi
    
    # Set owner as current keypair
    solana config set --keypair "$current_dir/owner.json"
    echo "🔑 Set owner as current keypair"
    
    # Create ops and hot wallets
    if ! create_or_recover_wallet "ops"; then
        echo "❌ Failed to create ops wallet"
        return 1
    fi
    
    if ! create_or_recover_wallet "hot"; then
        echo "❌ Failed to create hot wallet"
        return 1
    fi
    
    # Get wallet addresses
    local owner_address=$(get_wallet_address "owner")
    local ops_address=$(get_wallet_address "ops")
    local hot_address=$(get_wallet_address "hot")
    
    if [[ -z "$owner_address" || -z "$ops_address" || -z "$hot_address" ]]; then
        echo "❌ Failed to get wallet addresses"
        return 1
    fi
    
    # Create token mint
    echo ""
    echo "🪙 Creating Token Mint"
    echo "====================="
    
    local mint_address
    if [[ -f "USDC_mint.txt" ]]; then
        mint_address=$(get_token_mint "USDC")
        # Validate that the mint address is not empty and exists on-chain
        if [[ -n "$mint_address" ]] && solana account "$mint_address" >/dev/null 2>&1; then
            echo "✅ Found existing USDC mint: $mint_address"
        else
            echo "⚠️  USDC mint file exists but mint is invalid or doesn't exist on-chain"
            echo "🔄 Creating new USDC mint..."
            if ! create_token_mint "USDC" 6 "$owner_address"; then
                echo "❌ Failed to create USDC token mint"
                return 1
            fi
            mint_address=$(get_token_mint "USDC")
        fi
    else
        echo "📝 USDC mint file not found, creating new mint..."
        if ! create_token_mint "USDC" 6 "$owner_address"; then
            echo "❌ Failed to create USDC token mint"
            return 1
        fi
        mint_address=$(get_token_mint "USDC")
    fi
    
    # Create Associated Token Accounts (ATAs)
    echo ""
    echo "🏦 Creating Associated Token Accounts"
    echo "===================================="
    
    # Create ATA for owner (current keypair)
    if ! createAta "$owner_address" "$mint_address" "owner"; then
        echo "❌ Failed to create ATA for owner"
        return 1
    fi
    
    # Create ATAs for ops and hot wallets
    if ! createAta "$ops_address" "$mint_address" "ops"; then
        echo "❌ Failed to create ATA for ops"
        return 1
    fi
    
    if ! createAta "$hot_address" "$mint_address" "hot"; then
        echo "❌ Failed to create ATA for hot"
        return 1
    fi
    
    # Get ATA addresses
    local owner_ata=$(get_ata_address "$owner_address" "$mint_address")
    local ops_ata=$(get_ata_address "$ops_address" "$mint_address")
    local hot_ata=$(get_ata_address "$hot_address" "$mint_address")
    
    # Mint tokens
    echo ""
    echo "💰 Minting Tokens"
    echo "================="
    
    # Mint tokens to each wallet
    if ! mintTokens "$mint_address" 1000000 "$owner_ata" "owner"; then
        echo "❌ Failed to mint tokens to owner"
        return 1
    fi
    
    if ! mintTokens "$mint_address" 500000 "$ops_ata" "ops"; then
        echo "❌ Failed to mint tokens to ops"
        return 1
    fi
    
    if ! mintTokens "$mint_address" 250000 "$hot_ata" "hot"; then
        echo "❌ Failed to mint tokens to hot"
        return 1
    fi
    
    # Final summary
    echo ""
    echo "🎉 Local Solana Node Initialization Complete!"
    echo "============================================="
    echo "📍 Owner address: $owner_address"
    echo "📍 Ops address: $ops_address"
    echo "📍 Hot address: $hot_address"
    echo "🪙 USDC mint: $mint_address"
    echo ""
    echo "💰 Token balances:"
    echo "  - Owner: $(get_token_balance "$owner_address" "$mint_address") USDC"
    echo "  - Ops: $(get_token_balance "$ops_address" "$mint_address") USDC"
    echo "  - Hot: $(get_token_balance "$hot_address" "$mint_address") USDC"
    echo ""
    echo "✅ All wallets created and funded successfully!"
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    initializeLocalSolNode
fi 