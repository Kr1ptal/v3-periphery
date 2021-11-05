// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '../interfaces/ITickLens.sol';
import "../base/Multicall.sol";

/// @title Tick Lens contract
contract TickLens is ITickLens {
    /// @inheritdoc ITickLens
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        public
        view
        override
        returns (PopulatedTick[] memory populatedTicks)
    {
        // fetch bitmap
        uint256 bitmap = IUniswapV3Pool(pool).tickBitmap(tickBitmapIndex);

        // calculate the number of populated ticks
        uint256 numberOfPopulatedTicks;
        for (uint256 i = 0; i < 256; i++) {
            if (bitmap & (1 << i) > 0) numberOfPopulatedTicks++;
        }

        // fetch populated tick data
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);
        for (uint256 i = 0; i < 256; i++) {
            if (bitmap & (1 << i) > 0) {
                int24 populatedTick = ((int24(tickBitmapIndex) << 8) + int24(i)) * tickSpacing;
                (uint128 liquidityGross, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(pool).ticks(populatedTick);
                populatedTicks[--numberOfPopulatedTicks] = PopulatedTick({
                    tick: populatedTick,
                    liquidityNet: liquidityNet,
                    liquidityGross: liquidityGross
                });
            }
        }
    }

    function getInitializedTickRange(address pool, uint8 wordRange)
        public
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity, PopulatedTick[] memory populatedTicks)
    {
        liquidity = IUniswapV3Pool(pool).liquidity();
        ( sqrtPriceX96, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
        int16 startWordIndex = int16(tick >> 8);

        // first, count initialized tickers
        uint256 numberOfPopulatedTicks;
        int16 wordEndIndex = startWordIndex + int16(wordRange);
        for (int16 wordIndex = startWordIndex; wordIndex < wordEndIndex; wordIndex++) {
            uint256 bitmap = IUniswapV3Pool(pool).tickBitmap(wordIndex);
            for (uint256 i = 0; i < 256; i++) {
               if (bitmap & (1 << i) > 0) {
                   numberOfPopulatedTicks++;
               }
            }
        }

        wordEndIndex = startWordIndex - int16(wordRange);
        for (int16 wordIndex = startWordIndex - 1; wordIndex >= wordEndIndex; wordIndex--) {
            uint256 bitmap = IUniswapV3Pool(pool).tickBitmap(wordIndex);
            for (uint256 i = 0; i < 256; i++) {
               if (bitmap & (1 << i) > 0) {
                   numberOfPopulatedTicks++;
               }
            }
        }

        // then, fetch populated tick data
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);
        wordEndIndex = startWordIndex + int16(wordRange);
        for (int16 wordIndex = startWordIndex; wordIndex < wordEndIndex; wordIndex++) {
            uint256 bitmap = IUniswapV3Pool(pool).tickBitmap(wordIndex);
            for (uint256 i = 0; i < 256; i++) {
               if (bitmap & (1 << i) == 0) {
                   continue;
               }
               int24 populatedTick = ((int24(wordIndex) << 8) + int24(i)) * tickSpacing;
               (uint128 liquidityGross, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(pool).ticks(populatedTick);
               populatedTicks[--numberOfPopulatedTicks] = PopulatedTick({
                   tick: populatedTick,
                   liquidityNet: liquidityNet,
                   liquidityGross: liquidityGross
               });
            }
        }
        wordEndIndex = startWordIndex - int16(wordRange);
        for (int16 wordIndex = startWordIndex - 1; wordIndex >= wordEndIndex; wordIndex--) {
            uint256 bitmap = IUniswapV3Pool(pool).tickBitmap(wordIndex);
            for (uint256 i = 0; i < 256; i++) {
               if (bitmap & (1 << i) == 0) {
                   continue;
               }
               int24 populatedTick = ((int24(wordIndex) << 8) + int24(i)) * tickSpacing;
               (uint128 liquidityGross, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(pool).ticks(populatedTick);
               populatedTicks[--numberOfPopulatedTicks] = PopulatedTick({
                  tick: populatedTick,
                  liquidityNet: liquidityNet,
                  liquidityGross: liquidityGross
              });
            }
        }
    }
}
