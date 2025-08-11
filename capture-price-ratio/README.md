# Capture Price Ratio

This notebook downloads Australian NEM data from AEMO, and calculates the capture price ratio (and participation factor) of generators grouped by fuel type, over time.

`add-swap.sh` is to create a file on Linux and register it as a swap partition. This is required because this notebook uses a lot of memory - more than what a typical laptop has. This is to handle the per-generator power level aggregation.
