#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/wallet-utils.sh"
source "$SCRIPT_DIR/token-utils.sh"

# Function to show usage
show_usage() {
    echo "🪙 Send Tokens between wallets"
    echo "=============================="
    echo ""
    echo "Usage: $0 --amount <amount> --from <wallet_type> --to <wallet_type>"
    echo ""
    echo "Parameters:"
    echo "  --amount <amount>     Amount of tokens to send (e.g., 100 for 100 USDC)"
    echo "  --from <wallet_type>  Source wallet (owner, ops, or hot)"
    echo "  --to <wallet_type>    Destination wallet (owner, ops, or hot)"
    echo ""
    echo "Examples:"
    echo "  $0 --amount 1000 --from owner --to ops"
    echo "  $0 --amount 50.5 --from ops --to hot"
    echo ""
    echo "Notes:"
    echo "  • Amount is in token units (e.g., USDC, not micro-USDC)"
    echo "  • Source and destination wallets must be different"
    echo "  • Source wallet must have sufficient token balance"
    echo "  • Both wallets must have Associated Token Accounts (ATAs)"
    echo "  • Currently supports USDC tokens"
}

# Function to validate token amount format
validate_amount() {
    local amount=$1
    
    # Check if amount is a valid number (integer or decimal)
    if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "❌ Invalid amount format: $amount"
        echo "💡 Amount must be a positive number (e.g., 100, 50.5, 1000)"
        return 1
    fi
    
    # Check if amount is greater than 0
    if (( $(echo "$amount <= 0" | bc -l) )); then
        echo "❌ Amount must be greater than 0"
        return 1
    fi
    
    return 0
}

# Function to check if wallet has sufficient token balance
check_token_balance() {
    local wallet_address=$1
    local mint_address=$2
    local required_amount=$3
    local wallet_name=$4
    
    # Check if ATA exists
    if ! ata_exists "$wallet_address" "$mint_address"; then
        echo "❌ $wallet_name wallet does not have an Associated Token Account (ATA)"
        echo "💡 Run './solana-local init' to create ATAs for all wallets"
        return 1
    fi
    
    # Get current token balance
    local current_balance=$(get_token_balance "$wallet_address" "$mint_address")
    
    if [[ -z "$current_balance" || "$current_balance" == "0" ]]; then
        echo "❌ $wallet_name wallet has no token balance"
        local ata_address=$(get_ata_address "$wallet_address" "$mint_address")
        echo "💡 ATA address: $ata_address"
        echo "💰 Mint tokens to this wallet first"
        return 1
    fi
    
    echo "💰 $wallet_name wallet token balance: $current_balance"
    
    # Check if we have enough balance
    if (( $(echo "$current_balance < $required_amount" | bc -l) )); then
        echo "❌ Insufficient token balance for transfer"
        echo "💡 Required: $required_amount, Available: $current_balance"
        return 1
    fi
    
    return 0
}

# Function to ensure destination ATA exists
ensure_destination_ata() {
    local wallet_address=$1
    local mint_address=$2
    local wallet_name=$3
    
    if ! ata_exists "$wallet_address" "$mint_address"; then
        echo "⚠️  Destination $wallet_name wallet does not have an ATA"
        echo "🔄 Creating ATA for $wallet_name wallet..."
        
        if ! createAta "$wallet_address" "$mint_address" "$wallet_name"; then
            echo "❌ Failed to create ATA for destination wallet"
            return 1
        fi
    else
        echo "✅ Destination $wallet_name wallet ATA exists"
    fi
    
    return 0
}

# Function to send tokens
send_token() {
    local amount=$1
    local from_wallet=$2
    local to_wallet=$3
    
    echo "🚀 Sending Tokens"
    echo "================="
    echo "🪙 Amount: $amount USDC"
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
    
    # Get USDC mint address
    local mint_address=$(get_token_mint "USDC")
    if [[ -z "$mint_address" ]]; then
        echo "❌ USDC mint not found"
        echo "💡 Run './solana-local init' to create the USDC mint"
        return 1
    fi
    
    echo "🪙 USDC mint: $mint_address"
    
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
    
    # Check if source wallet has sufficient token balance
    if ! check_token_balance "$from_address" "$mint_address" "$amount" "$from_wallet"; then
        return 1
    fi
    
    # Ensure destination ATA exists
    if ! ensure_destination_ata "$to_address" "$mint_address" "$to_wallet"; then
        return 1
    fi
    
    echo ""
    echo "🔄 Executing token transfer..."
    
    # Store current keypair
    local current_keypair=$(solana config get | grep "Keypair Path" | awk '{print $3}')
    
    # Set the source wallet as the current keypair
    local from_wallet_file="${from_wallet}.json"
    solana config set --keypair "$from_wallet_file" >/dev/null 2>&1
    
    # Get source ATA address
    local from_ata=$(get_ata_address "$from_address" "$mint_address")
    
    # Execute the token transfer
    local transfer_result=$(spl-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA transfer "$mint_address" "$amount" "$to_address" --fund-recipient 2>&1)
    local transfer_exit_code=$?
    
    # Restore original keypair
    solana config set --keypair "$current_keypair" >/dev/null 2>&1
    
    if [[ $transfer_exit_code -eq 0 ]]; then
        echo "✅ Successfully sent $amount USDC from $from_wallet to $to_wallet"
        
        # Show updated balances
        echo ""
        echo "📊 Updated Token Balances:"
        echo "=========================="
        local from_new_balance=$(get_token_balance "$from_address" "$mint_address")
        local to_new_balance=$(get_token_balance "$to_address" "$mint_address")
        echo "📤 $from_wallet wallet: $from_new_balance USDC"
        echo "📥 $to_wallet wallet: $to_new_balance USDC"
        
        # Extract transaction signature if available
        local signature=$(echo "$transfer_result" | grep -o '[A-Za-z0-9]\{87,88\}' | head -1)
        if [[ -n "$signature" ]]; then
            echo ""
            echo "🔗 Transaction signature: $signature"
        fi
        
        return 0
    else
        echo "❌ Failed to send tokens"
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
send_token "$amount" "$from_wallet" "$to_wallet" 