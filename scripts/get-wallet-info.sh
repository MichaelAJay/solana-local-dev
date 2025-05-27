#!/bin/bash

# Script to extract wallet information and return as JSON
# Usage: ./get-wallet-info.sh <wallet_type>
# where wallet_type is either 'ops' or 'hot'
#
# ⚠️  SECURITY WARNING ⚠️
# This script will display your PRIVATE KEY in PLAINTEXT!
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
    echo "where wallet_type is either 'ops' or 'hot'"
    echo ""
    echo "⚠️  WARNING: This script displays private keys in plaintext!"
    echo "Example: $0 ops"
}

# Function to get user confirmation
confirm_execution() {
    echo ""
    echo "⚠️  SECURITY WARNING ⚠️"
    echo "======================================"
    echo "This script will display your PRIVATE KEY in PLAINTEXT!"
    echo ""
    echo "Risks:"
    echo "  • Private key will be visible on screen"
    echo "  • Output may be captured in logs or recordings"
    echo "  • Accidental sharing could compromise your wallet"
    echo ""
    echo "⚠️  STATE WARNING ⚠️"
    echo "======================================"
    echo "Keypair information is always valid, but on-chain state is ephemeral:"
    echo "  • Restarting the validator clears all on-chain accounts"
    echo "  • SOL balances and token accounts will be reset"
    echo "  • You may need to run './solana-local init' after validator restarts"
    echo "  • The keypair itself remains valid and can be reused"
    echo ""
    echo "Only proceed if:"
    echo "  • You are in a secure, private environment"
    echo "  • You are not screen sharing or recording"
    echo "  • You understand the security implications"
    echo "  • You understand the ephemeral nature of local validator state"
    echo ""
    read -p "Do you want to continue and display the private key? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled for security."
        exit 0
    fi
    echo ""
}

# Function to convert byte array to hex string
bytes_to_hex() {
    local bytes_str="$1"
    # Remove brackets and split by comma
    local bytes_array=($(echo "$bytes_str" | tr -d '[]' | tr ',' ' '))
    local hex_string=""
    
    for byte in "${bytes_array[@]}"; do
        # Convert to hex and pad with zero if needed
        hex_string+=$(printf "%02x" "$byte")
    done
    
    echo "$hex_string"
}

# Function to convert base58 address to hex
base58_to_hex() {
    local wallet_file="${wallet_type}.json"
    
    # The keypair file contains 64 bytes: 32 private key + 32 public key
    # Extract bytes 32-63 (the public key portion) and convert to hex
    local pubkey_bytes=$(cat "$wallet_file" | jq -r '.[32:64] | map(. | tostring) | join(",")')
    
    if [[ -n "$pubkey_bytes" && "$pubkey_bytes" != "null" ]]; then
        # Convert the comma-separated byte values to hex
        echo "$pubkey_bytes" | tr ',' '\n' | while read byte; do 
            printf "%02x" "$byte"
        done
    else
        # Fallback: return empty string if extraction fails
        echo ""
    fi
}

# Function to convert first 32 bytes to base58 (private key)
bytes_to_base58_privkey() {
    local wallet_file="$1"
    
    # Extract first 32 bytes and create a temporary keypair file with just those bytes
    local first_32_bytes=$(cat "$wallet_file" | jq -r '.[0:32]')
    local temp_file=$(mktemp)
    echo "$first_32_bytes" > "$temp_file"
    
    # Use solana-keygen to convert to base58 format
    # Since solana-keygen expects a full keypair, we need a different approach
    # Let's use the existing bytes_to_hex function and then convert to base58
    local hex_privkey=$(echo "$first_32_bytes" | jq -r 'map(. | tostring) | join(",")' | tr ',' '\n' | while read byte; do printf "%02x" "$byte"; done)
    
    # For now, let's use a simpler approach - create a minimal keypair with just the private key
    # and extract it using Solana tools
    
    # Actually, let's use the fact that we can create a keypair from the seed
    # The first 32 bytes ARE the seed, so we can use solana-keygen to recover the keypair
    # and then extract just the private key portion
    
    # Create a temporary file with the seed bytes
    printf '%s' "$first_32_bytes" | jq -r 'map(.) | @json' > "$temp_file"
    
    # Use a different approach: convert the bytes directly to base58
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
import sys

# Simple base58 encoding without external dependencies
def base58_encode(data):
    alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    
    # Convert bytes to integer
    num = 0
    for byte in data:
        num = num * 256 + byte
    
    # Convert to base58
    if num == 0:
        return alphabet[0]
    
    result = ''
    while num > 0:
        num, remainder = divmod(num, 58)
        result = alphabet[remainder] + result
    
    # Add leading zeros
    for byte in data:
        if byte == 0:
            result = alphabet[0] + result
        else:
            break
    
    return result

# Read the bytes from the temp file
with open('$temp_file', 'r') as f:
    bytes_array = json.load(f)

# Convert to bytes and encode
byte_data = bytes(bytes_array)
print(base58_encode(byte_data))
" 2>/dev/null
    else
        # Fallback: return hex if base58 encoding fails
        echo "$hex_privkey"
    fi
    
    # Clean up
    rm -f "$temp_file"
}

# Function to extract wallet info and return as JSON
get_wallet_info() {
    local wallet_type=$1
    local wallet_file="${wallet_type}.json"
    
    # Check if local validator is running
    if ! check_local_validator; then
        return 1
    fi
    
    # Check if wallet file exists
    if [[ ! -f "$wallet_file" ]]; then
        echo "Could not find ${wallet_type}.json. Have you run \`./solana-local init\`?" >&2
        exit 1
    fi
    
    # Extract public key (which is also the address in Solana)
    local pubkey=$(solana-keygen pubkey "$wallet_file" 2>/dev/null)
    if [[ $? -ne 0 || -z "$pubkey" ]]; then
        echo "Failed to extract public key from ${wallet_file}" >&2
        exit 1
    fi
    
    # Extract the first 32 bytes (private key seed)
    local privkey_bytes=$(cat "$wallet_file" | jq -r '.[0:32]')
    if [[ -z "$privkey_bytes" || "$privkey_bytes" == "null" ]]; then
        echo "Failed to read private key from ${wallet_file}" >&2
        exit 1
    fi
    
    # Convert the private key bytes to base58
    local privkey_base58=$(bytes_to_base58_privkey "$wallet_file")
    
    # In Solana, address and public key are the same (base58 format)
    local address="$pubkey"
    
    # Convert the address to hex format for pubKey field
    local pubkey_hex=$(base58_to_hex "$wallet_type")
    
    # Check if account exists on-chain and has SOL balance
    local account_exists="false"
    local has_sol_balance="false"
    local sol_balance="0"
    
    # Check if base account exists (has SOL balance)
    sol_balance=$(solana balance "$address" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+(\.[0-9]+)?$' || echo "0")
    if [[ "$sol_balance" != "0" ]]; then
        account_exists="true"
        has_sol_balance="true"
    fi
    
    # If no SOL balance, check if account exists but is empty
    if [[ "$account_exists" == "false" ]]; then
        if solana account "$address" >/dev/null 2>&1; then
            account_exists="true"
        fi
    fi
    
    # Output the JSON with base58 privKey and hex-encoded pubKey
    echo "{\"address\": \"$address\", \"privKey\": \"$privkey_base58\", \"pubKey\": \"$pubkey_hex\"}"
    
    # Provide detailed state information as console output
    echo "" >&2
    if [[ "$has_sol_balance" == "true" ]]; then
        echo "✅ On-chain account exists with $sol_balance SOL balance" >&2
    elif [[ "$account_exists" == "true" ]]; then
        echo "⚠️  On-chain account exists but has 0 SOL balance" >&2
        echo "💡 Account needs SOL for rent (~0.00089 SOL minimum)" >&2
        echo "💰 Run 'solana airdrop 1 $address' to fund the account" >&2
    else
        echo "⚠️  No on-chain account found for this address" >&2
        echo "💡 Account will be created when it receives SOL or tokens" >&2
        echo "💰 Run 'solana airdrop 1 $address' to create and fund the account" >&2
        echo "🔧 Or run './solana-local init' to set up everything including token accounts" >&2
    fi
}

# Main script logic
if [[ $# -eq 0 ]]; then
    echo "Error: Missing wallet type parameter" >&2
    show_usage
    exit 1
fi

wallet_type="$1"

# Validate wallet type
if [[ "$wallet_type" != "ops" && "$wallet_type" != "hot" ]]; then
    echo "Only supported for 'ops' and 'hot'" >&2
    exit 1
fi

# Get user confirmation before proceeding
confirm_execution

# Get wallet info and output JSON
get_wallet_info "$wallet_type" 