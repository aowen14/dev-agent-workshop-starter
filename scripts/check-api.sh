#!/usr/bin/env bash
# Quick API health check for /check-ui skill

echo "=== Health ==="
curl -s http://localhost:8001/api/health 2>&1

echo ""
echo "=== Stats ==="
curl -s http://localhost:8001/api/stats 2>&1

echo ""
echo "=== Products (sample) ==="
curl -s http://localhost:8001/api/products 2>&1 | python3 -c "
import sys, json
try:
    products = json.load(sys.stdin)
    print(f'{len(products)} products loaded')
    print()
    for p in products[:8]:
        name = p['name']
        cat = p['category']
        stock = p['stock']
        status = p['status']
        print(f'  {name:30s} {cat:12s} stock={stock:>4d}  {status}')
    if len(products) > 8:
        print(f'  ... and {len(products) - 8} more')
except Exception as e:
    print(f'Error: {e}')
"
