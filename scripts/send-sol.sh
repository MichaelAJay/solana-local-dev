#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/wallet-utils.sh"

# Function to show usage
show_usage() {
    echo "💸 Send SOL between wallets"
    echo "==========================="
    echo ""
    echo "Usage: $0 --amount <amount> --from <wallet_type> --to <wallet_type>"
    echo ""
    echo "Parameters:"
    echo "  --amount <amount>     Amount of SOL to send (e.g., 1.5 for 1.5 SOL)"
    echo "  --from <wallet_type>  Source wallet (owner, ops, or hot)"
    echo "  --to <wallet_type>    Destination wallet (owner, ops, or hot)"
    echo ""
    echo "Examples:"
    echo "  $0 --amount 1.5 --from owner --to ops"
    echo "  $0 --amount 0.1 --from ops --to hot"
    echo ""
    echo "Notes:"
    echo "  • Amount is in SOL (not lamports)"
    echo "  • Source and destination wallets must be different"
    echo "  • Source wallet must have sufficient SOL balance"
    echo "  • Minimum rent-exempt balance (~0.00089 SOL) will be preserved"
}

# Function to validate SOL amount format
validate_amount() {
    local amount=$1
    
    # Check if amount is a valid number (integer or decimal)
    if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "❌ Invalid amount format: $amount"
        echo "💡 Amount must be a positive number (e.g., 1.5, 0.1, 10)"
        return 1
    fi
    
    # Check if amount is greater than 0
    if (( $(echo "$amount <= 0" | bc -l) )); then
        echo "❌ Amount must be greater than 0"
        return 1
    fi
    
    return 0
}

# Function to check if wallet has sufficient SOL balance
check_sol_balance() {
    local wallet_address=$1
    local required_amount=$2
    local wallet_name=$3
    
    # Get current SOL balance
    local current_balance=$(solana balance "$wallet_address" 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$current_balance" || "$current_balance" == "0" ]]; then
        echo "❌ $wallet_name wallet has no SOL balance"
        echo "💡 Run 'solana airdrop 2 $wallet_address' to fund the wallet"
        return 1
    fi
    
    # Calculate minimum balance to keep (rent-exempt amount)
    local min_balance="0.00089"  # Approximate rent-exempt balance for basic account
    local available_balance=$(echo "$current_balance - $min_balance" | bc -l)
    
    echo "💰 $wallet_name wallet balance: $current_balance SOL"
    echo "🔒 Rent-exempt reserve: $min_balance SOL"
    echo "💸 Available for transfer: $available_balance SOL"
    
    # Check if we have enough available balance
    if (( $(echo "$available_balance < $required_amount" | bc -l) )); then
        echo "❌ Insufficient available balance for transfer"
        echo "💡 Required: $required_amount SOL, Available: $available_balance SOL"
        echo "💰 Fund the wallet with: solana airdrop $(echo "$required_amount + 1" | bc -l) $wallet_address"
        return 1
    fi
    
    return 0
}

# Function to send SOL
send_sol() {
    local amount=$1
    local from_wallet=$2
    local to_wallet=$3
    
    echo "🚀 Sending SOL"
    echo "=============="
    echo "💸 Amount: $amount SOL"
    echo "📤 From: $from_wallet wallet"
    echo "📥 To: $to_wallet wallet"
    echo ""
    
    # Check if local validator is running
    if ! check_local_validator; then
        return 1
    fi
    
    # Validate wallet types
    for wallet in "$from_wallet" "$to_wallet"; do
        if [[ "$wallet" != "owner" && "$wallet" != "ops" && "$wallet" != "hot" ]]; then
            echo "❌ Invalid wallet type: $wallet"
            echo "💡 Valid wallet types: owner, ops, hot"
            return 1
        fi
    done
    
    # Check that from and to wallets are different
    if [[ "$from_wallet" == "$to_wallet" ]]; then
        echo "❌ Source and destination wallets must be different"
        return 1
    fi
    
    # Validate amount format
    if ! validate_amount "$amount"; then
        return 1
    fi
    
    # Get wallet addresses
    local from_address=$(get_wallet_address "$from_wallet")
    local to_address=$(get_wallet_address "$to_wallet")
    
    if [[ -z "$from_address" ]]; then
        echo "❌ Source wallet file ${from_wallet}.json not found"
        echo "💡 Run './solana-local init' to create wallets"
        return 1
    fi
    
    if [[ -z "$to_address" ]]; then
        echo "❌ Destination wallet file ${to_wallet}.json not found"
        echo "💡 Run './solana-local init' to create wallets"
        return 1
    fi
    
    echo "📍 From address: $from_address"
    echo "📍 To address: $to_address"
    echo ""
    
    # Check if source wallet has sufficient balance
    if ! check_sol_balance "$from_address" "$amount" "$from_wallet"; then
        return 1
    fi
    
    echo ""
    echo "🔄 Executing transfer..."
    
    # Store current keypair
    local current_keypair=$(solana config get | grep "Keypair Path" | awk '{print $3}')
    
    # Set the source wallet as the current keypair
    local from_wallet_file="${from_wallet}.json"
    solana config set --keypair "$from_wallet_file" >/dev/null 2>&1
    
    # Execute the transfer
    local transfer_result=$(solana transfer "$to_address" "$amount" --allow-unfunded-recipient 2>&1)
    local transfer_exit_code=$?
    
    # Restore original keypair
    solana config set --keypair "$current_keypair" >/dev/null 2>&1
    
    if [[ $transfer_exit_code -eq 0 ]]; then
        echo "✅ Successfully sent $amount SOL from $from_wallet to $to_wallet"
        
        # Show updated balances
        echo ""
        echo "📊 Updated Balances:"
        echo "==================="
        local from_new_balance=$(solana balance "$from_address" 2>/dev/null | awk '{print $1}')
        local to_new_balance=$(solana balance "$to_address" 2>/dev/null | awk '{print $1}')
        echo "📤 $from_wallet wallet: $from_new_balance SOL"
        echo "📥 $to_wallet wallet: $to_new_balance SOL"
        
        # Extract transaction signature if available
        local signature=$(echo "$transfer_result" | grep -o '[A-Za-z0-9]\{87,88\}' | head -1)
        if [[ -n "$signature" ]]; then
            echo ""
            echo "🔗 Transaction signature: $signature"
        fi
        
        return 0
    else
        echo "❌ Failed to send SOL"
        echo "Error: $transfer_result"
        return 1
    fi
}

# Parse command line arguments
amount=""
from_wallet=""
to_wallet=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --amount)
            amount="$2"
            shift 2
            ;;
        --from)
            from_wallet="$2"
            shift 2
            ;;
        --to)
            to_wallet="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown parameter: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# Check if all required parameters are provided
if [[ -z "$amount" || -z "$from_wallet" || -z "$to_wallet" ]]; then
    echo "❌ Missing required parameters"
    echo ""
    show_usage
    exit 1
fi

# Execute the transfer
send_sol "$amount" "$from_wallet" "$to_wallet" 