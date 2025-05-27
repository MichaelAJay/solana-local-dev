#!/bin/bash

# Function to check if local Solana test validator is running
check_local_validator() {
    echo "🔍 Checking if local Solana test validator is running..."
    
    # Check if we can connect to the local RPC endpoint
    local cluster_version=$(solana cluster-version 2>/dev/null)
    local rpc_url=$(solana config get | grep "RPC URL" | awk '{print $3}')
    
    if [[ $? -ne 0 || -z "$cluster_version" ]]; then
        echo ""
        echo "❌ Cannot connect to local Solana test validator"
        echo "🚨 ERROR: Local validator not running or not accessible"
        echo ""
        echo "💡 To start the local test validator, run:"
        echo "   solana-test-validator"
        echo ""
        echo "📋 Then try your command again once the validator is running."
        echo "   You should see output like 'Ledger location: test-ledger'"
        echo "   and 'JSON RPC URL: http://127.0.0.1:8899'"
        echo ""
        return 1
    fi
    
    # Check if we're connected to localhost
    if [[ "$rpc_url" != *"localhost"* && "$rpc_url" != *"127.0.0.1"* ]]; then
        echo ""
        echo "⚠️  WARNING: Not connected to local validator"
        echo "   Current RPC URL: $rpc_url"
        echo ""
        echo "💡 To connect to local validator, run:"
        echo "   solana config set --url localhost"
        echo ""
        echo "🚨 Then start the local test validator with:"
        echo "   solana-test-validator"
        echo ""
        return 1
    fi
    
    echo "✅ Local Solana test validator is running"
    echo "📍 RPC URL: $rpc_url"
    echo "🔗 Cluster version: $cluster_version"
    echo ""
    return 0
}

# If script is run directly (not sourced), run the check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_local_validator
fi 