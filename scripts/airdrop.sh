#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/wallet-utils.sh"

# Function to airdrop SOL to a wallet
airdrop() {
    local amount=$1
    local wallet_type=$2
    
    # Check if local validator is running
    if ! check_local_validator; then
        return 1
    fi
    
    # Validate inputs
    if [[ -z "$amount" || -z "$wallet_type" ]]; then
        echo "❌ Missing required parameters"
        echo "Usage: airdrop <amount> <wallet_type>"
        echo "Example: airdrop 5 ops"
        return 1
    fi
    
    # Validate amount is a positive number
    if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$amount <= 0" | bc -l) )); then
        echo "❌ Invalid amount: $amount"
        echo "Amount must be a positive number"
        echo "Example: airdrop 5 ops"
        return 1
    fi
    
    # Validate wallet type
    if [[ "$wallet_type" != "ops" && "$wallet_type" != "hot" && "$wallet_type" != "owner" ]]; then
        echo "❌ Invalid wallet type: $wallet_type"
        echo "Valid wallet types: ops, hot, owner"
        echo "Example: airdrop 5 ops"
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
    echo "💰 Airdropping SOL"
    echo "=================="
    echo "📍 Target wallet: $wallet_type ($wallet_address)"
    echo "💵 Amount: $amount SOL"
    
    # Get current balance
    local current_balance=$(solana balance "$wallet_address" 2>/dev/null | awk '{print $1}')
    if [[ -z "$current_balance" ]]; then
        current_balance="0"
    fi
    echo "💰 Current balance: $current_balance SOL"
    
    # Perform the airdrop
    echo ""
    echo "🚁 Performing airdrop..."
    local airdrop_result=$(solana airdrop "$amount" "$wallet_address" 2>&1)
    local airdrop_exit_code=$?
    
    if [[ $airdrop_exit_code -eq 0 ]]; then
        echo "✅ Airdrop successful!"
        
        # Get signature from result
        local signature=$(echo "$airdrop_result" | grep -o '[A-Za-z0-9]\{87,88\}')
        if [[ -n "$signature" ]]; then
            echo "📝 Transaction signature: $signature"
        fi
        
        # Wait a moment for balance to update
        sleep 2
        
        # Get new balance
        local new_balance=$(solana balance "$wallet_address" 2>/dev/null | awk '{print $1}')
        if [[ -n "$new_balance" ]]; then
            echo "💰 New balance: $new_balance SOL"
            
            # Calculate the actual amount received
            local received=$(echo "$new_balance - $current_balance" | bc -l)
            echo "📈 Amount received: $received SOL"
        fi
        
        echo ""
        echo "✅ Airdrop complete!"
        return 0
    else
        echo "❌ Airdrop failed!"
        echo "Error: $airdrop_result"
        
        # Provide helpful error messages
        if [[ "$airdrop_result" == *"airdrop request limit"* ]]; then
            echo ""
            echo "💡 Airdrop limit reached. Try again later or use a smaller amount."
        elif [[ "$airdrop_result" == *"Invalid"* ]]; then
            echo ""
            echo "💡 Invalid wallet address. Check that the wallet exists."
        fi
        
        return 1
    fi
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "❌ Missing required parameters"
        echo "Usage: $0 <amount> <wallet_type>"
        echo "Example: $0 5 ops"
        exit 1
    fi
    
    airdrop "$1" "$2"
fi 