// SPDX-License-Identifier: MIT

import {IMarket} from "./interfaces/IMarket.sol";
import {IMarketFactory} from "./interfaces/IMarketFactory.sol";
import {IOrderHandler} from "./interfaces/IOrderHandler.sol";
import {OrderInfo} from "./libraries/OrderInfo.sol";

pragma solidity 0.8.30;

contract Gate {
    IMarket public market;
    IMarketFactory public marketF;
    IOrderHandler public orderHandler;

    // Entrance Contract...

    constructor(address _marketF, address _orderHandler) {
        marketF = IMarketFactory(_marketF);
        orderHandler = IOrderHandler(_orderHandler);
    }

    function swapTokens(OrderInfo.SwapInfo memory swapInfo) public {
        if (swapInfo.orgChain == swapInfo.destChain) {
            require(marketF.getApprovedMarket(swapInfo.market), "Market is not whitelisted");
            _swapTokens(swapInfo);
        }
    }

    function longOrShort(OrderInfo.PerpPosition memory perpPosition) public {
        require(perpPosition.amount > 0 && 100 >= perpPosition.leverage, "Amount or leverage is invalid");
        _marketCheck(perpPosition);
        orderHandler.longOrShort(perpPosition);
    }

    function closePosition(uint256 _positionId, address _market) public {
        orderHandler.closePosition(_positionId, msg.sender, _market);
    }

    function depositLiquidity(uint256 _amountTokenA, uint256 _amountTokenB, address _market) public {
        require(marketF.getApprovedMarket(_market), "Market is not whitelisted");
        IMarket(_market).depositLiquidity(_amountTokenA, _amountTokenB, msg.sender);
    }

    function withdrawLiquidity(uint256 _amountTokenA, uint256 _amountTokenB, address _market) public {
        require(marketF.getApprovedMarket(_market), "Market is not whitelisted");
        IMarket(_market).withdrawLiquidity(_amountTokenA, _amountTokenB, msg.sender);
    }

    function liquidateUser(uint256 _positionId, address _market) public {
        require(marketF.getApprovedMarket(_market), "Market is not whitelisted");
        orderHandler.liquidateUser(_positionId, _market, msg.sender);
    }

    function _swapTokens(OrderInfo.SwapInfo memory swapInfo) internal {
        (uint256 balanceA, uint256 balanceB) = IMarket(swapInfo.market).getTokenBalances();
        if (swapInfo.buy) {
            // require(balanceA >= swapInfo.amountOut, "pool does not have enough balance");
            IMarket(swapInfo.market).swapToken(swapInfo);
        } else {
            // require(balanceB >= swapInfo.amountOut, "pool does not have enough balance");
            IMarket(swapInfo.market).swapToken(swapInfo);
        }
    }

    function _marketCheck(OrderInfo.PerpPosition memory perpPosition) internal {
        require(marketF.getApprovedMarket(perpPosition.market), "Market is not whitelisted");
        (uint256 tokenA, uint256 tokenB) = IMarket(perpPosition.market).getTokenBalances();
        uint256 collateral = perpPosition.amount * perpPosition.leverage;
        (address tokenAAddress, address tokenBAddress) =
            (IMarket(perpPosition.market).tokenA(), IMarket(perpPosition.market).tokenB());
        require(tokenA > collateral || tokenB > collateral, "Pool does not have enough tokens!");
        require(
            tokenAAddress == perpPosition.collateralToken || tokenBAddress == perpPosition.collateralToken,
            "collateraltoken needs to be equal to one of the market-assets"
        );
    }
}
