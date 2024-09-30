// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.20;

import "./FullMath.sol";
import "./SqrtPriceMath.sol";

/// @title Computes the result of a swap within ticks
/// @notice Contains methods for computing the result of a swap within a single tick price range, i.e., a single tick.
library SwapMath {
    /// @notice Computes the optimal amount to swap on pool0 and pool1 to maximise return within the given ticks, given the parameters of the swap
    /// @dev The final price should not be more extreme than the target price, which coule be more or less depending on direction of swap
    /// @param pool0sqrtRatioCurrentX96 The current sqrt price of pool0
    /// @param pool0sqrtRatioTargetX96 The price that cannot be exceeded in pool0, from which the direction of the swap is inferred
    /// @param pool0liquidity The usable liquidity in pool0
    /// @param pool0feePips The fee taken from the input amount into pool0, expressed in hundredths of a bip
    /// @param pool1sqrtRatioCurrentX96 The current sqrt price of pool1
    /// @param pool1sqrtRatioTargetX96 The price that cannot be exceeded in pool1, from which the direction of the swap is inferred
    /// @param pool1liquidity The usable liquidity in pool1
    /// @param pool1feePips The fee taken from the input amount into pool1, expressed in hundredths of a bip
    /// @return pool0sqrtRatioNextX96 The price after swapping the amount in/out from pool0, not to exceed the price target
    /// @return pool0amountIn The amount to be swapped into pool0, of either token0 or token1, based on the direction of the swap
    /// @return pool0amountOut The amount to be received from pool0, of either token0 or token1, based on the direction of the swap
    /// @return pool0feeAmount The amount of input into pool0 that will be taken as a fee
    /// @return pool1sqrtRatioNextX96 The price after swapping the amount in/out from pool1, not to exceed the price target
    /// @return pool1amountIn The amount to be swapped into pool1, of either token0 or token1, based on the direction of the swap
    /// @return pool1amountOut The amount to be received from pool1, of either token0 or token1, based on the direction of the swap
    /// @return pool1feeAmount The amount of input into pool1 that will be taken as a fee
    function computeSwapStepOptimal(
        uint160 pool0sqrtRatioCurrentX96,
        uint160 pool0sqrtRatioTargetX96,
        uint128 pool0liquidity,
        uint24 pool0feePips,
        uint160 pool1sqrtRatioCurrentX96,
        uint160 pool1sqrtRatioTargetX96,
        uint128 pool1liquidity,
        uint24 pool1feePips
    )
        internal
        pure
        returns (
            uint160 pool0sqrtRatioNextX96,
            uint256 pool0amountIn,
            uint256 pool0amountOut,
            uint256 pool0feeAmount,
            uint160 pool1sqrtRatioNextX96,
            uint256 pool1amountIn,
            uint256 pool1amountOut,
            uint256 pool1feeAmount
        )
    {
        bool zeroForOne = pool0sqrtRatioCurrentX96 >= pool0sqrtRatioTargetX96;
        if (zeroForOne) {
            uint256 pool0OptimalAmountIn = SqrtPriceMath.getOptimalAmount0Delta( // gives amountIn including fees, could change to be without to avoid unnecessary mulDiv calls
                pool0sqrtRatioCurrentX96,
                pool0liquidity,
                pool0feePips,
                pool1sqrtRatioCurrentX96,
                pool1liquidity,
                pool1feePips
            );
            uint256 pool0OptimalAmountInLessFee = FullMath.mulDiv( // MIGHT NEED TO ROUND UP FOR AMOUNTS IN
                pool0OptimalAmountIn,
                1e6 - pool0feePips,
                1e6
            );
            uint160 pool0OptimalsqrtRatioNextX96 = SqrtPriceMath
                .getNextSqrtPriceFromAmount0RoundingUp(
                    pool0sqrtRatioCurrentX96,
                    pool0liquidity,
                    pool0OptimalAmountInLessFee,
                    true
                );
            uint256 pool0OptimalAmountOut = SqrtPriceMath.getAmount1Delta(
                pool0sqrtRatioCurrentX96,
                pool0OptimalsqrtRatioNextX96,
                pool0liquidity,
                false
            );
            uint256 pool1OptimalAmountIn = FullMath.mulDiv( // Fees already removed for this value, so actual amountIn will have fees, is equal to pool0OptimalAmountOut
                pool0OptimalAmountOut,
                1e6 - pool1feePips,
                1e6
            );
            uint160 pool1OptimalsqrtRatioNextX96 = SqrtPriceMath
                .getNextSqrtPriceFromAmount1RoundingDown(
                    pool1sqrtRatioCurrentX96,
                    pool1liquidity,
                    pool1OptimalAmountIn,
                    true
                );
            uint256 pool1OptimalAmountOut = SqrtPriceMath.getAmount0Delta(
                pool1sqrtRatioCurrentX96,
                pool1OptimalsqrtRatioNextX96,
                pool1liquidity,
                false
            );
            uint256 pool0TargetAmountOut = SqrtPriceMath.getAmount1Delta(
                pool0sqrtRatioCurrentX96,
                pool0sqrtRatioTargetX96,
                pool0liquidity,
                false
            );
            uint256 pool0TargetAmountOutLessFee = FullMath.mulDiv( // Fee for pool1 removed for comparison with pool1TargetAmountIn which also excludes fees
                pool0TargetAmountOut,
                1e6 - pool1feePips,
                1e6
            );
            uint256 pool1TargetAmountIn = SqrtPriceMath.getAmount1Delta(
                pool1sqrtRatioCurrentX96,
                pool1sqrtRatioTargetX96,
                pool1liquidity,
                true
            );

            if (
                pool0OptimalAmountOut <= pool0TargetAmountOut && // CANT I JUST COMPARE PRICES INSTEAD OF CALCULATING ALL THE AMOUNTS????? - MIGHT ACTUALLY NOT MAKE MUCH DIFFERENCE, WILL KEEP AS IS FOR NOW
                pool1OptimalAmountIn <= pool1TargetAmountIn
            ) {
                // no next tick needed, at optimal value
                pool0sqrtRatioNextX96 = pool0OptimalsqrtRatioNextX96;
                pool0amountIn = pool0OptimalAmountInLessFee;
                pool0amountOut = pool0OptimalAmountOut;
                pool0feeAmount =
                    pool0OptimalAmountIn -
                    pool0OptimalAmountInLessFee; // since amountIn rounds down this effectively rounds up
                pool1sqrtRatioNextX96 = pool1OptimalsqrtRatioNextX96;
                pool1amountIn = pool1OptimalAmountIn;
                pool1amountOut = pool1OptimalAmountOut;
                pool1feeAmount = pool0OptimalAmountOut - pool1OptimalAmountIn; // since amountIn rounds down this effectively rounds up
            } else {
                // next tick should be for whichever target nexttick value is closer
                if (pool0TargetAmountOutLessFee >= pool1TargetAmountIn) {
                    // next tick should be for pool1
                    // change pool0 values to match pool1 optimal
                    pool0amountOut = FullMath.mulDiv(
                        pool1TargetAmountIn,
                        1e6,
                        1e6 - pool1feePips
                    );
                    pool0sqrtRatioNextX96 = SqrtPriceMath
                        .getNextSqrtPriceFromAmount1RoundingDown(
                            pool0sqrtRatioCurrentX96,
                            pool0liquidity,
                            pool0amountOut,
                            false
                        );
                    pool0amountIn = SqrtPriceMath.getAmount0Delta(
                        pool0sqrtRatioCurrentX96,
                        pool0sqrtRatioNextX96,
                        pool0liquidity,
                        true
                    );
                    pool0feeAmount = FullMath.mulDivRoundingUp(
                        pool0amountIn,
                        pool0feePips,
                        1e6 - pool0feePips
                    );
                    // change pool1 values to be at target
                    pool1sqrtRatioNextX96 = pool1sqrtRatioTargetX96;
                    pool1amountIn = pool1TargetAmountIn;
                    pool1amountOut = SqrtPriceMath.getAmount0Delta(
                        pool1sqrtRatioCurrentX96,
                        pool1sqrtRatioTargetX96,
                        pool1liquidity,
                        false
                    );
                    pool1feeAmount = pool0amountOut - pool1TargetAmountIn;
                } else {
                    // next tick should be for pool0
                    // change pool1 values to match pool0 optimal
                    pool1amountIn = pool0TargetAmountOutLessFee;
                    pool1sqrtRatioNextX96 = SqrtPriceMath
                        .getNextSqrtPriceFromAmount1RoundingDown(
                            pool1sqrtRatioCurrentX96,
                            pool1liquidity,
                            pool1amountIn,
                            true
                        );
                    pool1amountOut = SqrtPriceMath.getAmount0Delta(
                        pool1sqrtRatioCurrentX96,
                        pool1sqrtRatioNextX96,
                        pool1liquidity,
                        false
                    );
                    pool1feeAmount =
                        pool0TargetAmountOut -
                        pool0TargetAmountOutLessFee;
                    // change pool0 values to be at target
                    pool0sqrtRatioNextX96 = pool0sqrtRatioTargetX96;
                    pool0amountIn = SqrtPriceMath.getAmount0Delta(
                        pool0sqrtRatioCurrentX96,
                        pool0sqrtRatioTargetX96,
                        pool0liquidity,
                        true
                    );
                    pool0amountOut = pool0TargetAmountOut;
                    pool0feeAmount = FullMath.mulDivRoundingUp(
                        pool0amountIn,
                        pool0feePips,
                        1e6 - pool0feePips
                    );
                }
            }
        } else {
            uint256 pool0OptimalAmountIn = SqrtPriceMath.getOptimalAmount1Delta( // gives amountIn including fees, could change to be without to avoid unnecessary mulDiv calls
                pool1sqrtRatioCurrentX96,
                pool1liquidity,
                pool1feePips,
                pool0sqrtRatioCurrentX96,
                pool0liquidity,
                pool0feePips
            );
            uint256 pool0OptimalAmountInLessFee = FullMath.mulDiv(
                pool0OptimalAmountIn,
                1e6 - pool0feePips,
                1e6
            );
            uint160 pool0OptimalsqrtRatioNextX96 = SqrtPriceMath
                .getNextSqrtPriceFromAmount1RoundingDown(
                    pool0sqrtRatioCurrentX96,
                    pool0liquidity,
                    pool0OptimalAmountInLessFee,
                    true
                );
            uint256 pool0OptimalAmountOut = SqrtPriceMath.getAmount0Delta(
                pool0sqrtRatioCurrentX96,
                pool0OptimalsqrtRatioNextX96,
                pool0liquidity,
                false
            );
            uint256 pool1OptimalAmountIn = FullMath.mulDiv( // Fees already removed for this value, so actual amountIn will have fees, is equal to pool0OptimalAmountOut
                pool0OptimalAmountOut,
                1e6 - pool1feePips,
                1e6
            );
            uint160 pool1OptimalsqrtRatioNextX96 = SqrtPriceMath
                .getNextSqrtPriceFromAmount0RoundingUp(
                    pool1sqrtRatioCurrentX96,
                    pool1liquidity,
                    pool1OptimalAmountIn,
                    true
                );
            uint256 pool1OptimalAmountOut = SqrtPriceMath.getAmount1Delta(
                pool1sqrtRatioCurrentX96,
                pool1OptimalsqrtRatioNextX96,
                pool1liquidity,
                false
            );
            uint256 pool0TargetAmountOut = SqrtPriceMath.getAmount0Delta(
                pool0sqrtRatioCurrentX96,
                pool0sqrtRatioTargetX96,
                pool0liquidity,
                false
            );
            uint256 pool0TargetAmountOutLessFee = FullMath.mulDiv( // Fee for pool1 removed for comparison with pool1TargetAmountIn which also excludes fees
                pool0TargetAmountOut,
                1e6 - pool1feePips,
                1e6
            );
            uint256 pool1TargetAmountIn = SqrtPriceMath.getAmount0Delta(
                pool1sqrtRatioCurrentX96,
                pool1sqrtRatioTargetX96,
                pool1liquidity,
                true
            );
            if (
                pool0OptimalAmountOut <= pool0TargetAmountOut && // CANT I JUST COMPARE PRICES INSTEAD OF CALCULATING ALL THE AMOUNTS????? - MIGHT ACTUALLY NOT MAKE MUCH DIFFERENCE, WILL KEEP AS IS FOR NOW
                pool1OptimalAmountIn <= pool1TargetAmountIn
            ) {
                // no next tick needed, at optimal value
                pool0sqrtRatioNextX96 = pool0OptimalsqrtRatioNextX96;
                pool0amountIn = pool0OptimalAmountInLessFee;
                pool0amountOut = pool0OptimalAmountOut;
                pool0feeAmount =
                    pool0OptimalAmountIn -
                    pool0OptimalAmountInLessFee;
                pool1sqrtRatioNextX96 = pool1OptimalsqrtRatioNextX96;
                pool1amountIn = pool1OptimalAmountIn;
                pool1amountOut = pool1OptimalAmountOut;
                pool1feeAmount = pool0OptimalAmountOut - pool1OptimalAmountIn;
            } else {
                // next tick should be for whichever target nexttick value is closer
                if (pool0TargetAmountOutLessFee >= pool1TargetAmountIn) {
                    // next tick should be for pool1
                    // change pool0 values to match pool1 optimal
                    pool0amountOut = FullMath.mulDiv(
                        pool1TargetAmountIn,
                        1e6,
                        1e6 - pool1feePips
                    );
                    pool0sqrtRatioNextX96 = SqrtPriceMath
                        .getNextSqrtPriceFromAmount0RoundingUp(
                            pool0sqrtRatioCurrentX96,
                            pool0liquidity,
                            pool0amountOut,
                            false
                        );
                    pool0amountIn = SqrtPriceMath.getAmount1Delta(
                        pool0sqrtRatioCurrentX96,
                        pool0sqrtRatioNextX96,
                        pool0liquidity,
                        true
                    );
                    pool0feeAmount = FullMath.mulDivRoundingUp(
                        pool0amountIn,
                        pool0feePips,
                        1e6 - pool0feePips
                    );
                    // change pool1 values to be at target
                    pool1sqrtRatioNextX96 = pool1sqrtRatioTargetX96;
                    pool1amountIn = pool1TargetAmountIn;
                    pool1amountOut = SqrtPriceMath.getAmount1Delta(
                        pool1sqrtRatioCurrentX96,
                        pool1sqrtRatioTargetX96,
                        pool1liquidity,
                        false
                    );
                    pool1feeAmount = pool0amountOut - pool1TargetAmountIn;
                } else {
                    // next tick should be for pool0
                    // change pool1 values to match pool0 optimal
                    pool1amountIn = pool0TargetAmountOutLessFee;
                    pool1sqrtRatioNextX96 = SqrtPriceMath
                        .getNextSqrtPriceFromAmount0RoundingUp(
                            pool1sqrtRatioCurrentX96,
                            pool1liquidity,
                            pool1amountIn,
                            true
                        );
                    pool1amountOut = SqrtPriceMath.getAmount1Delta(
                        pool1sqrtRatioCurrentX96,
                        pool1sqrtRatioNextX96,
                        pool1liquidity,
                        false
                    );
                    pool1feeAmount =
                        pool0TargetAmountOut -
                        pool0TargetAmountOutLessFee;
                    // change pool0 values to be at target
                    pool0sqrtRatioNextX96 = pool0sqrtRatioTargetX96;
                    pool0amountIn = SqrtPriceMath.getAmount1Delta(
                        pool0sqrtRatioCurrentX96,
                        pool0sqrtRatioTargetX96,
                        pool0liquidity,
                        true
                    );
                    pool0amountOut = pool0TargetAmountOut;
                    pool0feeAmount = FullMath.mulDivRoundingUp(
                        pool0amountIn,
                        pool0feePips,
                        1e6 - pool0feePips
                    );
                }
            }
        }
    }
}
