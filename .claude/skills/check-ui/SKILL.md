---
name: check-ui
description: "Verify the inventory app UI by checking what's actually rendered in the browser"
disable-model-invocation: true
---

## Current API State

!`./scripts/check-api.sh 2>&1`

## Instructions

You have the API state above (injected automatically). Now verify the frontend matches.

1. **Read the injected API data** above to understand what the backend reports — total products, in_stock/low_stock/out_of_stock counts, and the sample product list.

2. **Open the frontend** using agent-browser:
   - Navigate to http://localhost:5174
   - Wait for the page to fully load
   - Take a snapshot of interactive elements
   - Take a screenshot and save it to /tmp/check-ui.png

3. **Compare UI vs API**:
   - Does the stats bar match the API stats (total, in_stock, low_stock, out_of_stock)?
   - Does the product table show the correct number of rows?
   - Are status badges showing the right colors? (green = In Stock, yellow = Low Stock, red = Out of Stock)

4. **Close the browser** when done.

5. **Report**:
   - What the API says (counts)
   - What the UI shows (counts, any mismatches)
   - Whether they match
   - One-line verdict
