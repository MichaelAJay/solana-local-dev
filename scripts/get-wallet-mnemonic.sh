#!/bin/bash

# Script to help with mnemonic phrases for Solana wallets
# Usage: ./get-wallet-mnemonic.sh <wallet_type>
# where wallet_type is either 'ops', 'hot', or 'owner'
#
# ⚠️  SECURITY WARNING ⚠️
# This script will display your MNEMONIC PHRASE in PLAINTEXT!
# - Do NOT run this while screen sharing or recording
# - Do NOT run this in environments where output may be logged
# - Do NOT copy/paste the output in insecure channels
# - Only use in secure, local development environments

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"

# Function to show usage
show_usage() {
    echo "Usage: $0 <wallet_type>"
    echo "where wallet_type is either 'ops', 'hot', or 'owner'"
    echo ""
    echo "⚠️  WARNING: This script displays mnemonic phrases in plaintext!"
    echo "This only works for wallets created with the updated init script."
    echo ""
    echo "Example: $0 ops"
}

# Function to get user confirmation
confirm_execution() {
    echo ""
    echo "⚠️  SECURITY WARNING ⚠️"
    echo "======================================"
    echo "This script will help you recover or create mnemonic phrases!"
    echo ""
    echo "Risks:"
    echo "  • Mnemonic phrases will be visible on screen"
    echo "  • Output may be captured in logs or recordings"
    echo "  • Accidental sharing could compromise your wallet"
    echo ""
    echo "Only proceed if:"
    echo "  • You are in a secure, private environment"
    echo "  • You are not screen sharing or recording"
    echo "  • You understand the security implications"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled for security."
        exit 0
    fi
    echo ""
}

# Function to create new wallet with mnemonic
create_wallet_with_mnemonic() {
    local wallet_type=$1
    local wallet_file="${wallet_type}.json"
    local backup_file="${wallet_type}_backup_$(date +%Y%m%d_%H%M%S).json"
    
    echo "🆕 Creating new $wallet_type wallet with mnemonic"
    echo "=============================================="
    
    # Backup existing wallet if it exists
    if [[ -f "$wallet_file" ]]; then
        echo "📋 Backing up existing wallet to: $backup_file"
        cp "$wallet_file" "$backup_file"
        
        local old_address=$(solana-keygen pubkey "$wallet_file" 2>/dev/null)
        echo "📍 Old wallet address: $old_address"
        echo ""
    fi
    
    echo "🔄 Generating new keypair with mnemonic..."
    echo "💡 The mnemonic phrase will be displayed below - SAVE IT SECURELY!"
    echo ""
    
    # Generate new keypair and capture output
    local keygen_output=$(solana-keygen new --outfile "$wallet_file" --no-bip39-passphrase --force 2>&1)
    
    if [[ $? -eq 0 ]]; then
        local new_address=$(solana-keygen pubkey "$wallet_file" 2>/dev/null)
        echo "✅ Successfully created new $wallet_type wallet"
        echo "📍 New wallet address: $new_address"
        echo ""
        
        # Extract and display the mnemonic
        local mnemonic=$(echo "$keygen_output" | grep -A 1 "Save this seed phrase" | tail -1 | xargs)
        if [[ -n "$mnemonic" ]]; then
            echo "🔑 MNEMONIC PHRASE FOR $wallet_type WALLET:"
            echo "=========================================="
            echo "$mnemonic"
            echo "=========================================="
            echo ""
            echo "⚠️  IMPORTANT: Write this phrase down and store it securely!"
            echo "⚠️  This is the ONLY way to recover your wallet!"
            echo ""
            
            if [[ -f "$backup_file" ]]; then
                echo "💡 Your old wallet was backed up to: $backup_file"
                echo "💡 You may need to transfer funds from the old address to the new one"
                echo "💡 Old address: $old_address"
                echo "💡 New address: $new_address"
            fi
        else
            echo "❌ Could not extract mnemonic phrase from output"
            echo "Raw output:"
            echo "$keygen_output"
        fi
        
        return 0
    else
        echo "❌ Failed to create new wallet"
        echo "Error: $keygen_output"
        return 1
    fi
}

# Function to test mnemonic recovery
test_mnemonic_recovery() {
    local wallet_type=$1
    
    echo "🧪 Testing mnemonic recovery for $wallet_type wallet"
    echo "================================================"
    echo "This will test if you can recover your wallet from a mnemonic phrase."
    echo ""
    read -p "Do you want to test mnemonic recovery? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "🔄 Starting recovery test..."
        echo "You will be prompted to enter your mnemonic phrase."
        echo ""
        
        local test_file="${wallet_type}_recovery_test.json"
        
        if solana-keygen recover --outfile "$test_file" prompt:; then
            local recovered_address=$(solana-keygen pubkey "$test_file" 2>/dev/null)
            local current_address=$(solana-keygen pubkey "${wallet_type}.json" 2>/dev/null)
            
            echo ""
            echo "✅ Recovery test completed!"
            echo "📍 Recovered address: $recovered_address"
            echo "📍 Current address:   $current_address"
            
            if [[ "$recovered_address" == "$current_address" ]]; then
                echo "🎉 SUCCESS: Addresses match! Your mnemonic is correct."
            else
                echo "⚠️  WARNING: Addresses don't match. This might be a different mnemonic."
            fi
            
            # Clean up test file
            rm -f "$test_file"
        else
            echo "❌ Recovery test failed"
        fi
    fi
}

# Main function
handle_wallet_mnemonic() {
    local wallet_type=$1
    local wallet_file="${wallet_type}.json"
    
    echo "🔍 Analyzing $wallet_type wallet"
    echo "=============================="
    
    if [[ -f "$wallet_file" ]]; then
        local address=$(solana-keygen pubkey "$wallet_file" 2>/dev/null)
        echo "📍 Current wallet address: $address"
        echo ""
        
        echo "❓ MNEMONIC STATUS: UNKNOWN"
        echo "=========================="
        echo "Your existing wallet file doesn't contain mnemonic information."
        echo "This wallet was likely created with an older version of the scripts."
        echo ""
        echo "💡 OPTIONS:"
        echo "1. Create a new wallet with a mnemonic (recommended)"
        echo "2. Test if you know the mnemonic for this wallet"
        echo "3. Keep using the current wallet without a mnemonic"
        echo ""
        
        read -p "What would you like to do? (1/2/3): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                echo ""
                create_wallet_with_mnemonic "$wallet_type"
                ;;
            2)
                echo ""
                test_mnemonic_recovery "$wallet_type"
                ;;
            3)
                echo ""
                echo "✅ Keeping current wallet without mnemonic changes."
                ;;
            *)
                echo ""
                echo "❌ Invalid option. Exiting."
                exit 1
                ;;
        esac
    else
        echo "❌ Wallet file not found: $wallet_file"
        echo "💡 Run './solana-local init' to create wallets"
        echo "💡 Or create a new wallet with mnemonic:"
        echo ""
        create_wallet_with_mnemonic "$wallet_type"
    fi
}

# Main script logic
if [[ $# -eq 0 ]]; then
    echo "Error: Missing wallet type parameter"
    show_usage
    exit 1
fi

wallet_type="$1"

# Validate wallet type
if [[ "$wallet_type" != "ops" && "$wallet_type" != "hot" && "$wallet_type" != "owner" ]]; then
    echo "Error: Invalid wallet type '$wallet_type'"
    echo "Valid wallet types: ops, hot, owner"
    exit 1
fi

# Get user confirmation before proceeding
confirm_execution

# Handle wallet mnemonic
handle_wallet_mnemonic "$wallet_type" 