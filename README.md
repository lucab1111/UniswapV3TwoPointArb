## UniswapV3TwoPointArb

**Foundry project to identify and execute two point arbitrage opportunities**
Algorithm found in **ArbOptimiser.sol**, models Concentrated Liquidity Pools as piecewise functions in the form XY = L<sup>2</sup>.
The locally optimal input amount is calculated within the current ticks for a pair of pools in **SwapMath.sol**.

Custom FlashRouteProcessors **FlashRouteProcessor.sol** and **FlashRouteProcessor2.sol** make use of custom InputStream libraries **InputStreamStorage.sol**
and **InputStreamCustom.sol** respectively.
**InputStreamStorage.sol** implements the InputStream logic from SushiSwap, but making use of storage instead of memory to allow access of data on re-entrancy.
Storage space is cleared after use to refund gas costs by calling **deleteStream** at the end of a transaction.

**InputStreamCustom.sol** builds on the original InputStream library by allowing the initial bytes variable to be shortened to only include the remaining data and be passed into the function of another contract for smaller parameter size and gas optimisation. This is achieved in the function **cutStreamToBytesRemaining**.

Token and factory addresses are correct as of most recent commit time for Polygon Mainnet.

NOTE: Runtime for all tokens can be very slow due to rpc node request latency. Most tokens commented to show possible arbitrage opportunities in reasonable time. Also by default gas costs are disregarded which is very unlikely to be profitable, but are set this way to demonstrate the ability of this algorithm to find genuine opportunities. Lines 264 and 265 of **ArbOptimiser.sol** should be uncommented and commented respectively to give a rough estimate of gas costs.

### Build

```shell
$ forge build
```

### Deploy simulating on chain transaction

Public node can be found at https://polygon.publicnode.com/, <your_rpc_url> can be set to https://polygon-bor-rpc.publicnode.com at time of most recent commit
Alternatively an Infura or Alchemy Polygon Mainnet node can be used.

```shell
$ forge script executeArb --chain 137 --rpc-url <your_rpc_url>
```

### Deploy simulating on chain transaction, then broadcasting transaction to mainnet

```shell
$ forge script executeArb --chain 137 --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```
