#!/bin/bash

# Source the validator check script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"

# Function to create or recover wallet
create_or_recover_wallet() {
    local wallet_name=$1
    local wallet_file="${wallet_name}.json"
    local current_dir=$(pwd)
    
    echo ""
    echo "🔑 Processing wallet: $wallet_name"
    echo "-----------------------------------"
    
    if [[ -f "$wallet_file" ]]; then
        echo "✅ Found existing wallet file: $wallet_file"
        echo "🔄 Using existing keypair..."
        
        # Get address from existing wallet without setting as current keypair
        local address=$(solana-keygen pubkey "$wallet_file")
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Successfully loaded $wallet_name wallet"
            echo "📍 Wallet address: $address"
            # No mnemonic available for existing wallets
            echo "" > "${wallet_name}_mnemonic.txt"
            return 0
        else
            echo "❌ Failed to read $wallet_name wallet"
            return 1
        fi
    else
        echo "📝 Creating new wallet: $wallet_name"
        
        # Generate new keypair and capture the mnemonic
        # We'll use --no-bip39-passphrase but remove --silent to capture the mnemonic
        local keygen_output=$(solana-keygen new --outfile "$wallet_file" --no-bip39-passphrase 2>&1)
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Successfully created $wallet_name wallet"
            
            local address=$(solana-keygen pubkey "$wallet_file")
            echo "📍 New wallet address: $address"
            
            # Extract and save the mnemonic phrase from the output
            local mnemonic=$(echo "$keygen_output" | grep -A 1 "Save this seed phrase" | tail -1 | xargs)
            if [[ -n "$mnemonic" ]]; then
                echo "$mnemonic" > "${wallet_name}_mnemonic.txt"
                echo "💾 Mnemonic saved for later display"
            else
                echo "⚠️  Could not extract mnemonic phrase"
                echo "" > "${wallet_name}_mnemonic.txt"
            fi
            
            # Airdrop some SOL for gas fees
            echo "💰 Airdropping 2 SOL for gas fees..."
            solana airdrop 2 "$address"
            
            return 0
        else
            echo "❌ Failed to create $wallet_name wallet"
            return 1
        fi
    fi
}

# Function to get wallet address from file
get_wallet_address() {
    local wallet_name=$1
    local wallet_file="${wallet_name}.json"
    
    if [[ -f "$wallet_file" ]]; then
        solana-keygen pubkey "$wallet_file"
    else
        echo ""
        return 1
    fi
}

# Function to create Associated Token Account (ATA)
createAta() {
    local wallet_address=$1
    local mint_address=$2
    local wallet_name=$3
    local current_dir=$(pwd)
    
    echo "📝 Creating ATA for $wallet_name ($wallet_address)..."
    
    # Check if ATA already exists by trying to get the address and checking if it exists on-chain
    local ata_address=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA address --verbose --owner "$wallet_address" --token "$mint_address" 2>/dev/null | grep "Associated token address:" | awk '{print $4}')
    if [[ -n "$ata_address" ]]; then
        # Check if the account actually exists on-chain by trying to get account info
        if solana account "$ata_address" >/dev/null 2>&1; then
            echo "✅ ATA already exists for $wallet_name: $ata_address"
            return 0
        fi
    fi
    
    # Try to create the ATA
    local create_result
    local current_address=$(solana address)
    if [[ "$wallet_address" == "$current_address" ]]; then
        # Create ATA for current keypair
        create_result=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA create-account "$mint_address" 2>&1)
    else
        # Create ATA for different owner, use owner keypair as fee payer
        create_result=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA create-account "$mint_address" --owner "$wallet_address" --fee-payer "$current_dir/owner.json" 2>&1)
    fi
    
    # Check if creation was successful or if account already exists
    if [[ $? -eq 0 ]]; then
        echo "✅ Successfully created ATA for $wallet_name"
        return 0
    elif [[ "$create_result" == *"Account already exists"* ]]; then
        echo "✅ ATA already exists for $wallet_name"
        return 0
    else
        echo "❌ Failed to create ATA for $wallet_name"
        echo "Error: $create_result"
        return 1
    fi
}

# Function to mint tokens to a specific account
mintTokens() {
    local mint_address=$1
    local amount=$2
    local token_account=$3
    local recipient_name=$4
    
    echo "💰 Minting $amount tokens to $recipient_name..."
    spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA mint "$mint_address" "$amount" "$token_account"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Successfully minted $amount tokens to $recipient_name"
        
        # Check balance
        local balance=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA balance "$mint_address" --owner "$token_account" 2>/dev/null)
        echo "💰 Current token balance for $recipient_name: $balance"
        return 0
    else
        echo "❌ Failed to mint tokens to $recipient_name"
        return 1
    fi
} 