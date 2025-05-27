#!/bin/bash

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-validator.sh"
source "$SCRIPT_DIR/token-utils.sh"

echo "🧪 Testing Token Mint Operations"
echo "================================"

# Check if local validator is running
if ! check_local_validator; then
    echo "❌ Local validator is not running. Please start it first."
    exit 1
fi

# Test 1: Check if USDC mint exists
echo ""
echo "Test 1: Checking USDC mint..."
mint_address=$(get_token_mint "USDC")
if [[ -n "$mint_address" ]]; then
    echo "✅ USDC mint found: $mint_address"
    
    # Verify it exists on-chain
    if solana account "$mint_address" >/dev/null 2>&1; then
        echo "✅ Mint exists on-chain"
    else
        echo "❌ Mint file exists but mint not found on-chain"
        echo "🔄 You may need to recreate the mint"
    fi
else
    echo "❌ USDC mint not found"
    echo "🔄 You may need to run the init script"
fi

# Test 2: Check wallet files
echo ""
echo "Test 2: Checking wallet files..."
for wallet in "owner" "ops" "hot"; do
    if [[ -f "${wallet}.json" ]]; then
        echo "✅ ${wallet}.json exists"
    else
        echo "❌ ${wallet}.json missing"
    fi
done

# Test 3: Check if we can get wallet addresses
echo ""
echo "Test 3: Checking wallet addresses..."
if [[ -f "owner.json" ]]; then
    owner_address=$(solana-keygen pubkey owner.json 2>/dev/null)
    if [[ -n "$owner_address" ]]; then
        echo "✅ Owner address: $owner_address"
    else
        echo "❌ Failed to get owner address"
    fi
fi

echo ""
echo "🏁 Test complete!"
echo ""
echo "💡 If any tests failed, try running:"
echo "   ./scripts/init-local-node.sh" 