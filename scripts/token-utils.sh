#!/bin/bash

# Source the validator check script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"

# Function to create a new token mint
create_token_mint() {
    local token_name=$1
    local decimals=${2:-9}  # Default to 9 decimals if not specified
    local mint_authority=$3  # Optional mint authority, defaults to current keypair
    
    echo ""
    echo "🪙 Creating token mint: $token_name"
    echo "-----------------------------------"
    
    # Build the create-token command
    local create_cmd="spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA create-token --decimals $decimals"
    
    # Add mint authority if specified
    if [[ -n "$mint_authority" ]]; then
        create_cmd="$create_cmd --mint-authority $mint_authority"
        echo "🔑 Setting mint authority to: $mint_authority"
    fi
    
    # Create the token mint
    local mint_address=$(eval "$create_cmd" | grep "Creating token" | awk '{print $3}')
    
    if [[ -n "$mint_address" ]]; then
        echo "✅ Successfully created token mint: $token_name"
        echo "📍 Mint address: $mint_address"
        
        # Save mint address to file for later reference
        echo "$mint_address" > "${token_name}_mint.txt"
        echo "💾 Saved mint address to ${token_name}_mint.txt"
        
        return 0
    else
        echo "❌ Failed to create token mint: $token_name"
        return 1
    fi
}

# Function to get token mint address from file
get_token_mint() {
    local token_name=$1
    local mint_file="${token_name}_mint.txt"
    
    if [[ -f "$mint_file" ]]; then
        cat "$mint_file"
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
    
    echo "🏦 Creating ATA for $wallet_name wallet"
    echo "  Wallet: $wallet_address"
    echo "  Mint: $mint_address"
    
    # Check if ATA already exists
    if ata_exists "$wallet_address" "$mint_address"; then
        local ata_address=$(get_ata_address "$wallet_address" "$mint_address")
        echo "✅ ATA already exists for $wallet_name: $ata_address"
        return 0
    fi
    
    # Store current keypair
    local current_keypair=$(solana config get | grep "Keypair Path" | awk '{print $3}')
    
    # Set the keypair to the wallet we want to create ATA for
    local wallet_file="${wallet_name}.json"
    if [[ -f "$wallet_file" ]]; then
        solana config set --keypair "$wallet_file" >/dev/null 2>&1
        
        # Create the ATA (this will create it for the current keypair)
        local result=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA create-account "$mint_address" 2>&1)
        
        # Restore original keypair
        solana config set --keypair "$current_keypair" >/dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            local ata_address=$(get_ata_address "$wallet_address" "$mint_address")
            echo "✅ Successfully created ATA for $wallet_name: $ata_address"
            return 0
        else
            echo "❌ Failed to create ATA for $wallet_name"
            echo "Error: $result"
            return 1
        fi
    else
        echo "❌ Wallet file not found: $wallet_file"
        return 1
    fi
}

# Function to mint tokens to an account
mintTokens() {
    local mint_address=$1
    local amount=$2
    local recipient_ata=$3
    local recipient_name=$4
    
    echo "💰 Minting $amount tokens to $recipient_name"
    echo "  Mint: $mint_address"
    echo "  Recipient ATA: $recipient_ata"
    
    # Store current keypair
    local current_keypair=$(solana config get | grep "Keypair Path" | awk '{print $3}')
    
    # Ensure we're using the owner keypair (mint authority) for minting
    if [[ -f "owner.json" ]]; then
        solana config set --keypair "owner.json" >/dev/null 2>&1
    fi
    
    # Mint the tokens
    local result=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA mint "$mint_address" "$amount" "$recipient_ata" 2>&1)
    local mint_exit_code=$?
    
    # Restore original keypair
    solana config set --keypair "$current_keypair" >/dev/null 2>&1
    
    if [[ $mint_exit_code -eq 0 ]]; then
        echo "✅ Successfully minted $amount tokens to $recipient_name"
        return 0
    else
        echo "❌ Failed to mint tokens to $recipient_name"
        echo "Error: $result"
        return 1
    fi
}

# Function to get Associated Token Account address
get_ata_address() {
    local wallet_address=$1
    local mint_address=$2
    
    spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA address --verbose --owner "$wallet_address" --token "$mint_address" 2>/dev/null | grep "Associated token address:" | awk '{print $4}'
}

# Function to check if ATA exists
ata_exists() {
    local wallet_address=$1
    local mint_address=$2
    
    local ata_address=$(get_ata_address "$wallet_address" "$mint_address")
    if [[ -n "$ata_address" ]]; then
        # Check if the account actually exists on-chain
        solana account "$ata_address" >/dev/null 2>&1
        return $?
    else
        return 1
    fi
}

# Function to get token balance for a wallet
get_token_balance() {
    local wallet_address=$1
    local mint_address=$2
    
    local ata_address=$(get_ata_address "$wallet_address" "$mint_address")
    if [[ -n "$ata_address" ]] && ata_exists "$wallet_address" "$mint_address"; then
        spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA balance "$mint_address" --owner "$wallet_address" 2>/dev/null
    else
        echo "0"
    fi
} 