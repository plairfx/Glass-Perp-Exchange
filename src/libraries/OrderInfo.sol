// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

library OrderInfo {
    struct SwapInfo {
        uint256 minAmountIn;
        uint256 amountOut;
        address market;
        address receiver;
        uint256 orgChain;
        uint256 destChain;
        bool buy;
    }

    struct PositionInfo {
        bool isLong;
        address trader;
        uint256 initialAmount;
        uint256 amount;
        address market;
        address collateralToken;
        uint256 stopLoss;
        uint256 takeProfit;
        uint256 limitOrder;
        uint256 leverage;
        uint256 liquidationPrice;
        uint256 entryPrice;
    }

    struct PerpPosition {
        bool isLong;
        address trader;
        uint256 initialAmount;
        uint256 amount;
        address market;
        address collateralToken;
        uint256 stopLoss;
        uint256 takeProfit;
        uint256 limitOrder;
        uint256 leverage;
        uint256 liquidationPrice;
    }

    struct MarketInfo {
        address tokenA;
        address tokenB;
        address gate;
        address priceOracleFeed;
        address L2Sequencer;
        address handler;
    }
}
