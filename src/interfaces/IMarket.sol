// SPDX-License-Identifier: MIT

import {OrderInfo} from "../libraries/OrderInfo.sol";

pragma solidity 0.8.30;

interface IMarket {
    function getTokenBalances() external view returns (uint256, uint256);
    function swapToken(OrderInfo.SwapInfo memory swapInfo) external;
    function depositLiquidity(uint256 _amountTokenA, uint256 _amountTokenB, address _sender) external;
    function withdrawLiquidity(uint256 _amountTokenA, uint256 _amountTokenB, address _sender) external;
    function accomodateLiquidation(
        OrderInfo.PositionInfo memory positionInfo,
        uint256 liquidationFee,
        address _receiver
    ) external;
    function getDecimals() external view returns (uint8, uint8);
    function getCurrentPrice() external view returns (int256);
    function tokenA() external view returns (address);
    function tokenB() external view returns (address);
}
