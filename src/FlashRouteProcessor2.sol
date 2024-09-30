// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/ITridentCLPool.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ICurve.sol";
import "./libraries/InputStreamCustom.sol";
import "./libraries/Approve.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

address constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
address constant IMPOSSIBLE_POOL_ADDRESS = 0x0000000000000000000000000000000000000001;
address constant INTERNAL_INPUT_SOURCE = 0x0000000000000000000000000000000000000000;

uint8 constant LOCKED = 2;
uint8 constant NOT_LOCKED = 1;

/// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
uint160 constant MIN_SQRT_RATIO = 4295128739;
/// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

/// @title A route processor for the Sushi Aggregator
/// @author Ilya Lyalin - Original RouteProcessor4
/// @author Luca Boccardo - Flash Swap and InputStreamCustom Modifications
contract FlashRouteProcessor2 is Ownable {
    using SafeERC20 for IERC20;
    using Approve for IERC20;
    using SafeERC20 for IERC20Permit;
    using InputStreamCustom for uint256;

    mapping(address => bool) public priviledgedUsers;
    address private lastCalledPool;

    uint8 private callbackUnlocked = NOT_LOCKED;

    modifier onlyOwnerOrPriviledgedUser() {
        require(
            msg.sender == owner() || priviledgedUsers[msg.sender],
            "RP: caller is not the owner or a privileged user"
        );
        _;
    }

    constructor(address[] memory priviledgedUserList) Ownable(msg.sender) {
        lastCalledPool = IMPOSSIBLE_POOL_ADDRESS;

        for (uint256 i = 0; i < priviledgedUserList.length; i++) {
            priviledgedUsers[priviledgedUserList[i]] = true;
        }
    }

    function setPriviledge(address user, bool priviledge) external onlyOwner {
        priviledgedUsers[user] = priviledge;
    }

    /// @notice For native unwrapping
    receive() external payable {}

    function withdraw(
        address token,
        uint256 amount
    ) external onlyOwnerOrPriviledgedUser {
        if (token == NATIVE_ADDRESS) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Error occurred withdrawing native");
        } else {
            IERC20(token).safeTransfer(address(msg.sender), amount);
        }
    }

    /// @notice Processes the route generated off-chain. Has a lock
    function processRoute(
        bytes memory route
    ) external payable onlyOwnerOrPriviledgedUser {
        processRouteInternal(route);
    }

    /// @notice Processes the route generated off-chain
    function processRouteInternal(bytes memory route) private {
        uint256 stream = InputStreamCustom.createStream(route);
        address tokenIn = stream.readAddress();
        uint256 amountIn = stream.readUint();
        swap(stream, INTERNAL_INPUT_SOURCE, tokenIn, amountIn);
    }

    /// @notice Makes swap
    /// @param stream Streamed program
    /// @param from Where to take liquidity for swap
    /// @param tokenIn Input token
    /// @param amountIn Amount of tokenIn to take for swap
    function swap(
        uint256 stream,
        address from, // Probably not needed anymore - will always be from contract
        address tokenIn,
        uint256 amountIn
    ) private returns (uint256) {
        uint8 poolType = stream.readUint8();
        if (poolType == 0) swapUniV2(stream, from, tokenIn, amountIn);
        else if (poolType == 1) return swapUniV3(stream, tokenIn, amountIn);
        else if (poolType == 2) wrapNative(stream, from, tokenIn, amountIn);
        else if (poolType == 3) swapTrident(stream);
        else if (poolType == 4) swapCurve(stream, from, tokenIn, amountIn);
        else revert("RouteProcessor: Unknown pool type");
        return 0; // TODO: Should have a return for all branches of if statement, this should never return here
    }

    /// @notice Wraps/unwraps native token
    /// @param stream [direction & fake, recipient, wrapToken?]
    /// @param from Where to take liquidity for swap
    /// @param tokenIn Input token
    /// @param amountIn Amount of tokenIn to take for swap
    function wrapNative(
        uint256 stream,
        address from,
        address tokenIn,
        uint256 amountIn
    ) private {
        uint8 directionAndFake = stream.readUint8();
        address to = stream.readAddress();

        if (directionAndFake & 1 == 1) {
            // wrap native
            address wrapToken = stream.readAddress();
            if (directionAndFake & 2 == 0)
                IWETH(wrapToken).deposit{value: amountIn}();
            if (to != address(this))
                IERC20(wrapToken).safeTransfer(to, amountIn);
        } else {
            // unwrap native
            if (directionAndFake & 2 == 0) {
                if (from == msg.sender)
                    IERC20(tokenIn).safeTransferFrom(
                        msg.sender,
                        address(this),
                        amountIn
                    );
                IWETH(tokenIn).withdraw(amountIn);
            }
            (bool success, ) = payable(to).call{value: amountIn}("");
            require(
                success,
                "RouteProcessor.wrapNative: Native token transfer failed"
            );
        }
    }

    /// @notice UniswapV2 pool swap
    /// @param stream [pool, direction, recipient, fee]
    /// @param from Where to take liquidity for swap
    /// @param tokenIn Input token
    /// @param amountIn Amount of tokenIn to take for swap
    function swapUniV2(
        uint256 stream,
        address from,
        address tokenIn,
        uint256 amountIn
    ) private {
        address pool = stream.readAddress();
        uint8 direction = stream.readUint8();
        address to = stream.readAddress();
        uint24 fee = stream.readUint24(); // pool fee in 1/1_000_000

        if (from == address(this)) IERC20(tokenIn).safeTransfer(pool, amountIn);
        else if (from == msg.sender)
            IERC20(tokenIn).safeTransferFrom(msg.sender, pool, amountIn);

        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(pool).getReserves();
        require(r0 > 0 && r1 > 0, "Wrong pool reserves");
        (uint256 reserveIn, uint256 reserveOut) = direction == 1
            ? (r0, r1)
            : (r1, r0);
        amountIn = IERC20(tokenIn).balanceOf(pool) - reserveIn; // tokens already were transferred

        uint256 amountInWithFee = amountIn * (1_000_000 - fee);
        uint256 amountOut = (amountInWithFee * reserveOut) /
            (reserveIn * 1_000_000 + amountInWithFee);
        (uint256 amount0Out, uint256 amount1Out) = direction == 1
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        IUniswapV2Pair(pool).swap(amount0Out, amount1Out, to, new bytes(0));
    }

    /// @notice Trident pool swap
    /// @param stream [pool, swapData]
    function swapTrident(uint256 stream) private {
        address pool = stream.readAddress();
        bytes memory swapData = stream.readBytes();
        IPool(pool).swap(swapData);
    }

    /// @notice UniswapV3 pool swap
    /// @param stream [pool, direction, recipient]
    /// @param tokenIn Input token
    /// @param amountIn Amount of tokenIn to take for swap
    function swapUniV3(
        uint256 stream,
        address tokenIn,
        uint256 amountIn
    ) private returns (uint256 amountOut) {
        address pool = stream.readAddress();
        bool zeroForOne = stream.readUint8() > 0;
        address prevLastCalledPool;

        if (callbackUnlocked == LOCKED) {
            prevLastCalledPool = lastCalledPool;
        }
        lastCalledPool = pool;
        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            callbackUnlocked == NOT_LOCKED
                ? abi.encodePacked(tokenIn, stream.cutStreamToBytesRemaining())
                : abi.encodePacked(tokenIn)
        );
        amountOut = zeroForOne ? uint256(-amount1) : uint256(-amount0);
        require(
            callbackUnlocked == LOCKED ||
                lastCalledPool == IMPOSSIBLE_POOL_ADDRESS,
            "RouteProcessor.swapUniV3: unexpected"
        ); // Just to be sure
        if (callbackUnlocked == LOCKED) {
            lastCalledPool = prevLastCalledPool;
        }
    }

    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public {
        require(
            msg.sender == lastCalledPool,
            "RouteProcessor.uniswapV3SwapCallback: call from unknown source"
        );
        int256 amount = amount0Delta > 0 ? amount0Delta : amount1Delta;
        require(
            amount > 0,
            "RouteProcessor.uniswapV3SwapCallback: not positive amount"
        );
        uint256 stream = InputStreamCustom.createStream(data);
        address tokenIn = stream.readAddress();
        if (callbackUnlocked == NOT_LOCKED) {
            // FLASH SWAP IMPLEMENTED, RECEIVE Y, THEN DEPOSIT X AS IF SWAPPING X FOR Y
            callbackUnlocked = LOCKED;
            uint256 amountOut = amount0Delta > 0
                ? uint256(-amount1Delta)
                : uint256(-amount0Delta);
            while (stream.isNotEmpty()) {
                address token = stream.readAddress();
                amountOut = swap(
                    stream,
                    INTERNAL_INPUT_SOURCE,
                    token,
                    amountOut
                );
            }
            require(amountOut >= uint256(amount), "No profit");
            lastCalledPool = IMPOSSIBLE_POOL_ADDRESS;
            IERC20(tokenIn).safeTransfer(msg.sender, uint256(amount));
            callbackUnlocked = NOT_LOCKED;
        } else {
            // NORMAL SWAP, JUST TRANSFER SWAP INPUT AMOUNT
            IERC20(tokenIn).safeTransfer(msg.sender, uint256(amount));
        }
    }

    /// @notice Called to `msg.sender` after executing a swap via IAlgebraPool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method _must_ be checked to be a AlgebraPool deployed by the canonical AlgebraFactory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IAlgebraPoolActions#swap call
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
    }

    /// @notice Called to `msg.sender` after executing a swap via PancakeV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the PancakeV3Pool#swap call
    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
    }

    /// @notice Curve pool swap. Legacy pools that don't return amountOut and have native coins are not supported
    /// @param stream [pool, poolType, fromIndex, toIndex, recipient, output token]
    /// @param from Where to take liquidity for swap
    /// @param tokenIn Input token
    /// @param amountIn Amount of tokenIn to take for swap
    function swapCurve(
        uint256 stream,
        address from,
        address tokenIn,
        uint256 amountIn
    ) private {
        address pool = stream.readAddress();
        uint8 poolType = stream.readUint8();
        int128 fromIndex = int8(stream.readUint8());
        int128 toIndex = int8(stream.readUint8());
        address to = stream.readAddress();
        address tokenOut = stream.readAddress();

        uint256 amountOut;
        if (tokenIn == NATIVE_ADDRESS) {
            amountOut = ICurve(pool).exchange{value: amountIn}(
                fromIndex,
                toIndex,
                amountIn,
                0
            );
        } else {
            if (from == msg.sender)
                IERC20(tokenIn).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amountIn
                );
            IERC20(tokenIn).approveSafe(pool, amountIn);
            if (poolType == 0)
                amountOut = ICurve(pool).exchange(
                    fromIndex,
                    toIndex,
                    amountIn,
                    0
                );
            else {
                uint256 balanceBefore = IERC20(tokenOut).balanceOf(
                    address(this)
                );
                ICurveLegacy(pool).exchange(fromIndex, toIndex, amountIn, 0);
                uint256 balanceAfter = IERC20(tokenOut).balanceOf(
                    address(this)
                );
                amountOut = balanceAfter - balanceBefore;
            }
        }

        if (to != address(this)) {
            if (tokenOut == NATIVE_ADDRESS) {
                (bool success, ) = payable(to).call{value: amountOut}("");
                require(
                    success,
                    "RouteProcessor.swapCurve: Native token transfer failed"
                );
            } else {
                IERC20(tokenOut).safeTransfer(to, amountOut);
            }
        }
    }
}
