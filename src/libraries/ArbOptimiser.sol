// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IUniswapV3Factory.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "./LowGasSafeMath.sol";
import "./SafeCast.sol";
import "./TickBitmap.sol";
import "./TickMath.sol";
import "./LiquidityMath.sol";
import "./SwapMath.sol";

library ArbOptimiser {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount already swapped in of the output/input asset
        int256 amountCalculatedIn;
        // the amount already swapped out of the output/input asset
        int256 amountCalculatedOut;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    function optimalTwoPointArbInput(
        address tokenIn,
        address tokenOut,
        uint24 fee0, // order of fees doesn't matter, will be swapped to be optimal
        uint24 fee1
    ) public view returns (int256, int256, bool) {
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(
            0x1F98431c8aD98523631AE4a59f267346ea31F984 // If deployed as contract, factory address should be in constructor
        );

        IUniswapV3Pool pool0 = IUniswapV3Pool(
            uniswapV3Factory.getPool(tokenIn, tokenOut, fee0)
        );
        IUniswapV3Pool pool1 = IUniswapV3Pool(
            uniswapV3Factory.getPool(tokenIn, tokenOut, fee1)
        );

        (uint160 pool0slot0sqrtPriceX96, int24 pool0slot0tick, , , , , ) = pool0
            .slot0();
        (uint160 pool1slot0sqrtPriceX96, int24 pool1slot0tick, , , , , ) = pool1
            .slot0();

        // TODO: NEED TO FIND A WAY TO KNOW WETHER TOKEN1 OR TOKEN2 IS BETTER TO SWAP FIRST
        bool zeroForOne = tokenIn < tokenOut; // zeroForOne true means for first pool in swap
        bool poolSwapped = false;

        // Swap pool0 and pool1 along with other variables depending on which pool should be swapped on first
        if (pool0slot0sqrtPriceX96 < pool1slot0sqrtPriceX96 == zeroForOne) {
            poolSwapped = true;
            (pool0, pool1) = (pool1, pool0);
            (pool0slot0sqrtPriceX96, pool1slot0sqrtPriceX96) = (
                pool1slot0sqrtPriceX96,
                pool0slot0sqrtPriceX96
            );
            (pool0slot0tick, pool1slot0tick) = (pool1slot0tick, pool0slot0tick);
            (fee0, fee1) = (fee1, fee0);
        }

        int24 pool0tickSpacing = pool0.tickSpacing();
        int24 pool1tickSpacing = pool1.tickSpacing();

        (
            uint160 pool0sqrtPriceLimitX96,
            uint160 pool1sqrtPriceLimitX96
        ) = zeroForOne
                ? (TickMath.MIN_SQRT_RATIO + 1, TickMath.MAX_SQRT_RATIO - 1)
                : (TickMath.MAX_SQRT_RATIO - 1, TickMath.MIN_SQRT_RATIO + 1);

        SwapState memory pool0state = SwapState({
            amountCalculatedIn: 0,
            amountCalculatedOut: 0,
            sqrtPriceX96: pool0slot0sqrtPriceX96,
            tick: pool0slot0tick,
            liquidity: pool0.liquidity()
        });

        SwapState memory pool1state = SwapState({
            amountCalculatedIn: 0,
            amountCalculatedOut: 0,
            sqrtPriceX96: pool1slot0sqrtPriceX96,
            tick: pool1slot0tick,
            liquidity: pool1.liquidity()
        });

        bool pool0NextPriceReached = true;
        bool pool1NextPriceReached = true;

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (
            pool0state.sqrtPriceX96 != pool0sqrtPriceLimitX96 &&
            pool1state.sqrtPriceX96 != pool1sqrtPriceLimitX96 &&
            (pool0NextPriceReached || pool1NextPriceReached) &&
            (pool0state.liquidity != 0 && pool1state.liquidity != 0)
        ) {
            pool0NextPriceReached = false;
            pool1NextPriceReached = false;
            StepComputations memory pool0step;

            pool0step.sqrtPriceStartX96 = pool0state.sqrtPriceX96;

            (pool0step.tickNext, pool0step.initialized) = TickBitmap
                .nextInitializedTickWithinOneWord(
                    pool0,
                    pool0state.tick,
                    pool0tickSpacing,
                    zeroForOne
                );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (pool0step.tickNext < TickMath.MIN_TICK) {
                pool0step.tickNext = TickMath.MIN_TICK;
            } else if (pool0step.tickNext > TickMath.MAX_TICK) {
                pool0step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            pool0step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(
                pool0step.tickNext
            );

            StepComputations memory pool1step;

            pool1step.sqrtPriceStartX96 = pool1state.sqrtPriceX96;

            (pool1step.tickNext, pool1step.initialized) = TickBitmap
                .nextInitializedTickWithinOneWord(
                    pool1,
                    pool1state.tick,
                    pool1tickSpacing,
                    !zeroForOne
                );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (pool1step.tickNext < TickMath.MIN_TICK) {
                pool1step.tickNext = TickMath.MIN_TICK;
            } else if (pool1step.tickNext > TickMath.MAX_TICK) {
                pool1step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            pool1step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(
                pool1step.tickNext
            );

            // compute values to swap to the target tick, price limit, or point where input/output amount is optimal
            (
                pool0state.sqrtPriceX96,
                pool0step.amountIn,
                pool0step.amountOut,
                pool0step.feeAmount,
                pool1state.sqrtPriceX96,
                pool1step.amountIn,
                pool1step.amountOut,
                pool1step.feeAmount
            ) = SwapMath.computeSwapStepOptimal(
                pool0state.sqrtPriceX96,
                (
                    zeroForOne
                        ? pool0step.sqrtPriceNextX96 < pool0sqrtPriceLimitX96
                        : pool0step.sqrtPriceNextX96 > pool0sqrtPriceLimitX96
                )
                    ? pool0sqrtPriceLimitX96
                    : pool0step.sqrtPriceNextX96,
                pool0state.liquidity,
                fee0,
                pool1state.sqrtPriceX96,
                (
                    // Modified to assume zeroForOne is for pool0, but could have made mistake so double check
                    zeroForOne
                        ? pool1step.sqrtPriceNextX96 > pool1sqrtPriceLimitX96
                        : pool1step.sqrtPriceNextX96 < pool1sqrtPriceLimitX96
                )
                    ? pool1sqrtPriceLimitX96
                    : pool1step.sqrtPriceNextX96,
                pool1state.liquidity,
                fee1
            );

            pool0state.amountCalculatedIn = pool0state.amountCalculatedIn.add(
                (pool0step.amountIn + pool0step.feeAmount).toInt256()
            );
            pool0state.amountCalculatedOut = pool0state.amountCalculatedOut.sub(
                pool0step.amountOut.toInt256()
            );
            pool1state.amountCalculatedIn = pool1state.amountCalculatedIn.add(
                (pool1step.amountIn + pool1step.feeAmount).toInt256()
            );
            pool1state.amountCalculatedOut = pool1state.amountCalculatedOut.sub(
                pool1step.amountOut.toInt256()
            );

            // shift tick if we reached the next price
            if (pool0state.sqrtPriceX96 == pool0step.sqrtPriceNextX96) {
                pool0NextPriceReached = true;
                // if the tick is initialized, run the tick transition
                if (pool0step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    (, int128 liquidityNet, , , , , , ) = pool0.ticks(
                        pool0step.tickNext
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (zeroForOne) liquidityNet = -liquidityNet;

                    pool0state.liquidity = LiquidityMath.addDelta(
                        pool0state.liquidity,
                        liquidityNet
                    );
                }

                pool0state.tick = zeroForOne
                    ? pool0step.tickNext - 1
                    : pool0step.tickNext;
            } else if (pool0state.sqrtPriceX96 != pool0step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                pool0state.tick = TickMath.getTickAtSqrtRatio(
                    pool0state.sqrtPriceX96
                );
            }

            // shift tick if we reached the next price
            if (pool1state.sqrtPriceX96 == pool1step.sqrtPriceNextX96) {
                pool1NextPriceReached = true;
                // if the tick is initialized, run the tick transition
                if (pool1step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    (, int128 liquidityNet, , , , , , ) = pool1.ticks(
                        pool1step.tickNext
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (!zeroForOne) liquidityNet = -liquidityNet;

                    pool1state.liquidity = LiquidityMath.addDelta(
                        pool1state.liquidity,
                        liquidityNet
                    );
                }

                pool1state.tick = zeroForOne
                    ? pool1step.tickNext
                    : pool1step.tickNext - 1; // flipped for pool1 but double check
            } else if (pool1state.sqrtPriceX96 != pool1step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                pool1state.tick = TickMath.getTickAtSqrtRatio(
                    pool1state.sqrtPriceX96
                );
            }
        }
        if (pool0state.amountCalculatedIn >= -(pool1state.amountCalculatedOut))
            (pool0state.amountCalculatedIn, pool1state.amountCalculatedOut) = (
                0,
                0
            );
        return (
            pool0state.amountCalculatedIn,
            pool1state.amountCalculatedOut,
            poolSwapped
        );
        // STATE VALUES AT THE END WILL BE THE NEW VALUES ON CHAIN IF ACTUALLY SWAPPED AND AMOUNTS ARE NONZERO - ONLY SQRTPRICEX96, TICK and LIQUIDITY MATTER I THINK
    }

    function optimalTwoPointArbInputPool(
        address pool0Address,
        address pool1Address,
        uint24 fee0, // order of fees doesn't matter, will be swapped to be optimal
        uint24 fee1,
        bool zeroForOne
    ) public view returns (int256, int256, bool) {
        IUniswapV3Pool pool0 = IUniswapV3Pool(pool0Address);
        IUniswapV3Pool pool1 = IUniswapV3Pool(pool1Address);

        (uint160 pool0slot0sqrtPriceX96, int24 pool0slot0tick, , , , , ) = pool0
            .slot0();
        (uint160 pool1slot0sqrtPriceX96, int24 pool1slot0tick, , , , , ) = pool1
            .slot0();

        // TODO: NEED TO FIND A WAY TO KNOW WETHER TOKEN1 OR TOKEN2 IS BETTER TO SWAP FIRST
        bool poolSwapped = false;

        // Swap pool0 and pool1 along with other variables depending on which pool should be swapped on first
        if (pool0slot0sqrtPriceX96 < pool1slot0sqrtPriceX96 && zeroForOne) {
            poolSwapped = true;
            (pool0, pool1) = (pool1, pool0);
            (pool0slot0sqrtPriceX96, pool1slot0sqrtPriceX96) = (
                pool1slot0sqrtPriceX96,
                pool0slot0sqrtPriceX96
            );
            (pool0slot0tick, pool1slot0tick) = (pool1slot0tick, pool0slot0tick);
            (fee0, fee1) = (fee1, fee0);
        }

        int24 pool0tickSpacing = pool0.tickSpacing();
        int24 pool1tickSpacing = pool1.tickSpacing();

        (
            uint160 pool0sqrtPriceLimitX96,
            uint160 pool1sqrtPriceLimitX96
        ) = zeroForOne
                ? (TickMath.MIN_SQRT_RATIO + 1, TickMath.MAX_SQRT_RATIO - 1)
                : (TickMath.MAX_SQRT_RATIO - 1, TickMath.MIN_SQRT_RATIO + 1);

        SwapState memory pool0state = SwapState({
            amountCalculatedIn: 0,
            amountCalculatedOut: 0,
            sqrtPriceX96: pool0slot0sqrtPriceX96,
            tick: pool0slot0tick,
            liquidity: pool0.liquidity()
        });

        SwapState memory pool1state = SwapState({
            amountCalculatedIn: 0,
            amountCalculatedOut: 0,
            sqrtPriceX96: pool1slot0sqrtPriceX96,
            tick: pool1slot0tick,
            liquidity: pool1.liquidity()
        });

        bool pool0NextPriceReached = true;
        bool pool1NextPriceReached = true;

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (
            pool0state.sqrtPriceX96 != pool0sqrtPriceLimitX96 &&
            pool1state.sqrtPriceX96 != pool1sqrtPriceLimitX96 &&
            (pool0NextPriceReached || pool1NextPriceReached) &&
            (pool0state.liquidity != 0 && pool1state.liquidity != 0)
        ) {
            pool0NextPriceReached = false;
            pool1NextPriceReached = false;
            StepComputations memory pool0step;

            pool0step.sqrtPriceStartX96 = pool0state.sqrtPriceX96;

            (pool0step.tickNext, pool0step.initialized) = TickBitmap
                .nextInitializedTickWithinOneWord(
                    pool0,
                    pool0state.tick,
                    pool0tickSpacing,
                    zeroForOne
                );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (pool0step.tickNext < TickMath.MIN_TICK) {
                pool0step.tickNext = TickMath.MIN_TICK;
            } else if (pool0step.tickNext > TickMath.MAX_TICK) {
                pool0step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            pool0step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(
                pool0step.tickNext
            );

            StepComputations memory pool1step;

            pool1step.sqrtPriceStartX96 = pool1state.sqrtPriceX96;

            (pool1step.tickNext, pool1step.initialized) = TickBitmap
                .nextInitializedTickWithinOneWord(
                    pool1,
                    pool1state.tick,
                    pool1tickSpacing,
                    !zeroForOne
                );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (pool1step.tickNext < TickMath.MIN_TICK) {
                pool1step.tickNext = TickMath.MIN_TICK;
            } else if (pool1step.tickNext > TickMath.MAX_TICK) {
                pool1step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            pool1step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(
                pool1step.tickNext
            );

            // compute values to swap to the target tick, price limit, or point where input/output amount is optimal
            (
                pool0state.sqrtPriceX96,
                pool0step.amountIn,
                pool0step.amountOut,
                pool0step.feeAmount,
                pool1state.sqrtPriceX96,
                pool1step.amountIn,
                pool1step.amountOut,
                pool1step.feeAmount
            ) = SwapMath.computeSwapStepOptimal(
                pool0state.sqrtPriceX96,
                (
                    zeroForOne
                        ? pool0step.sqrtPriceNextX96 < pool0sqrtPriceLimitX96
                        : pool0step.sqrtPriceNextX96 > pool0sqrtPriceLimitX96
                )
                    ? pool0sqrtPriceLimitX96
                    : pool0step.sqrtPriceNextX96,
                pool0state.liquidity,
                fee0,
                pool1state.sqrtPriceX96,
                (
                    // Modified to assume zeroForOne is for pool0, but could have made mistake so double check
                    zeroForOne
                        ? pool1step.sqrtPriceNextX96 > pool1sqrtPriceLimitX96
                        : pool1step.sqrtPriceNextX96 < pool1sqrtPriceLimitX96
                )
                    ? pool1sqrtPriceLimitX96
                    : pool1step.sqrtPriceNextX96,
                pool1state.liquidity,
                fee1
            );

            pool0state.amountCalculatedIn = pool0state.amountCalculatedIn.add(
                (pool0step.amountIn + pool0step.feeAmount).toInt256()
            );
            pool0state.amountCalculatedOut = pool0state.amountCalculatedOut.sub(
                pool0step.amountOut.toInt256()
            );
            pool1state.amountCalculatedIn = pool1state.amountCalculatedIn.add(
                (pool1step.amountIn + pool1step.feeAmount).toInt256()
            );
            pool1state.amountCalculatedOut = pool1state.amountCalculatedOut.sub(
                pool1step.amountOut.toInt256()
            );

            // shift tick if we reached the next price
            if (pool0state.sqrtPriceX96 == pool0step.sqrtPriceNextX96) {
                pool0NextPriceReached = true;
                // if the tick is initialized, run the tick transition
                if (pool0step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    (, int128 liquidityNet, , , , , , ) = pool0.ticks(
                        pool0step.tickNext
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (zeroForOne) liquidityNet = -liquidityNet;

                    pool0state.liquidity = LiquidityMath.addDelta(
                        pool0state.liquidity,
                        liquidityNet
                    );
                }

                pool0state.tick = zeroForOne
                    ? pool0step.tickNext - 1
                    : pool0step.tickNext;
            } else if (pool0state.sqrtPriceX96 != pool0step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                pool0state.tick = TickMath.getTickAtSqrtRatio(
                    pool0state.sqrtPriceX96
                );
            }

            // shift tick if we reached the next price
            if (pool1state.sqrtPriceX96 == pool1step.sqrtPriceNextX96) {
                pool1NextPriceReached = true;
                // if the tick is initialized, run the tick transition
                if (pool1step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    (, int128 liquidityNet, , , , , , ) = pool1.ticks(
                        pool1step.tickNext
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (!zeroForOne) liquidityNet = -liquidityNet;

                    pool1state.liquidity = LiquidityMath.addDelta(
                        pool1state.liquidity,
                        liquidityNet
                    );
                }

                pool1state.tick = zeroForOne
                    ? pool1step.tickNext
                    : pool1step.tickNext - 1; // flipped for pool1 but double check
            } else if (pool1state.sqrtPriceX96 != pool1step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                pool1state.tick = TickMath.getTickAtSqrtRatio(
                    pool1state.sqrtPriceX96
                );
            }
        }
        if (pool0state.amountCalculatedIn >= -(pool1state.amountCalculatedOut))
            (pool0state.amountCalculatedIn, pool1state.amountCalculatedOut) = (
                0,
                0
            );
        return (
            pool0state.amountCalculatedIn,
            pool1state.amountCalculatedOut,
            poolSwapped
        );
        // STATE VALUES AT THE END WILL BE THE NEW VALUES ON CHAIN IF ACTUALLY SWAPPED AND AMOUNTS ARE NONZERO - ONLY SQRTPRICEX96, TICK and LIQUIDITY MATTER I THINK
    }
}
