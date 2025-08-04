// SPDX-License-Identifier: MIT

import {OrderInfo} from "./libraries/OrderInfo.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.8.30;

contract OrderHandler is Ownable {
    mapping(uint256 _positionId => OrderInfo.PositionInfo) positionInfo;
    mapping(uint256 _positionId => bool liquidated) userLiquidated;

    event Test(uint256, uint256);

    address gate;
    uint256 positionId;
    uint256 LIQUIDATION_FEE = 1e16; // 1% .
    uint256 POSITION_FEE = 5e15; // 0.05% for opening and closing positions.

    modifier onlyGate() {
        _onlyGate();
        _;
    }

    constructor(address _gov) Ownable(_gov) {}

    function longOrShort(OrderInfo.PerpPosition memory perpPosition) public onlyGate {
        IERC20(perpPosition.collateralToken).transferFrom(
            perpPosition.trader, address(perpPosition.market), perpPosition.initialAmount
        );

        (uint8 tdA, uint8 tdB) = IMarket(perpPosition.market).getDecimals();

        int256 _price = IMarket(perpPosition.market).getCurrentPrice();

        uint256 convertedPrice = uint256(_price) * 1e10;

        uint256 multiplier = 100 ether + LIQUIDATION_FEE; // 101 ether for 1% fee
        uint256 final_price = (convertedPrice * multiplier) / 100 ether;

        if (perpPosition.isLong) {
            uint256 _amount = perpPosition.amount;
            if (perpPosition.leverage > 1) {
                _amount = perpPosition.amount * perpPosition.leverage;
            }
            uint256 convertedCollateral = _amount * 1e10;
            uint256 liquidationPrice = final_price * (perpPosition.leverage - 1) / perpPosition.leverage;
            perpPosition.liquidationPrice = liquidationPrice;
            emit Test(convertedPrice, 0);
            emit Test(liquidationPrice, final_price);

            _initializePosition(perpPosition, final_price);
        } else {
            uint256 _amount = perpPosition.amount;
            // for shorts it needs to be -.
            uint256 _multiplier = 100 ether - LIQUIDATION_FEE; // 101 ether for 1% fee
            uint256 _final_price = (convertedPrice * _multiplier) / 100 ether;

            if (perpPosition.leverage > 1) {
                _amount = perpPosition.amount * perpPosition.leverage;
            }
            uint256 convertedCollateral = _amount * 1e10;
            uint256 liquidationPrice = _final_price * (1 + 1 / perpPosition.leverage);
            perpPosition.liquidationPrice = liquidationPrice;

            _initializePosition(perpPosition, _final_price);
        }
    }

    function closePosition(uint256 _positionId, address _receiver, address market) public onlyGate {
        OrderInfo.PositionInfo memory posInfo = positionInfo[_positionId];
        require(posInfo.trader == _receiver, "trader needs to be equal to receiver");
        require(!userLiquidated[_positionId], "User already liquidated!");

        uint256 _price = uint256(IMarket(market).getCurrentPrice()) * 1e10;

        uint256 _entryPrice = posInfo.entryPrice;

        // calculate the profits.. or losses.
        if (posInfo.isLong) {
            if (_price > _entryPrice) {
                uint256 profitinPercentage = (_price - _entryPrice) * 1 ether / _entryPrice;
                uint256 totalProfit = (posInfo.amount * profitinPercentage) / 1e18;

                uint256 AmountToReceive = totalProfit + posInfo.initialAmount;

                IERC20(posInfo.collateralToken).transfer(_receiver, AmountToReceive);
            } else {
                if (posInfo.liquidationPrice > _price) {
                    revert("Position Can only be liquidated!");
                }
                uint256 lossInPercentage = (_entryPrice - _price) * 1 ether / _entryPrice;

                uint256 totalLoss = (posInfo.initialAmount * lossInPercentage) / 1e18;

                if (totalLoss >= posInfo.amount) {
                    // check if its possible to liquidate or not.
                }

                uint256 amountToReceive = posInfo.initialAmount - totalLoss;

                emit Test(amountToReceive, totalLoss);
                IERC20(posInfo.collateralToken).transfer(_receiver, amountToReceive);
            }
        } else {
            if (_entryPrice > _price) {
                uint256 profitinPercentage = (_entryPrice - _price) * 1 ether / _entryPrice;

                uint256 totalProfit = ((posInfo.amount * profitinPercentage)) / 1e18;

                uint256 amountToReceive = posInfo.amount + totalProfit;

                IERC20(posInfo.collateralToken).transfer(_receiver, amountToReceive);
            } else {
                if (_price > posInfo.liquidationPrice) {
                    // internal liquidate function...
                }

                uint256 lossPercentage = (_price - _entryPrice) * 1 ether / _entryPrice;
                uint256 totalLoss = ((posInfo.initialAmount * lossPercentage)) / 1e18;
                emit Test(lossPercentage, totalLoss);

                uint256 amountRemaining = posInfo.initialAmount - totalLoss;
                IERC20(posInfo.collateralToken).transfer(_receiver, amountRemaining);
            }
        }
    }

    function liquidateUser(uint256 _positionID, address market, address _liquidator) public onlyGate {
        OrderInfo.PositionInfo memory perpInfo = positionInfo[_positionID];

        uint256 _price = uint256(IMarket(market).getCurrentPrice()) * 1e10;

        emit Test(_price, perpInfo.liquidationPrice);

        require(!userLiquidated[_positionID], "User already liquidated!");
        if (perpInfo.isLong) {
            require(perpInfo.liquidationPrice >= _price, "User cannot be liquidated yet!");
        } else {
            require(_price >= perpInfo.liquidationPrice, "User cannot be liquidated yet!");
        }

        uint256 amountSplit = perpInfo.initialAmount / 100 ether;
        uint256 liqFee = amountSplit * LIQUIDATION_FEE;

        IMarket(perpInfo.market).accomodateLiquidation(perpInfo, LIQUIDATION_FEE, _liquidator);
    }

    function setGate(address _gate) public onlyOwner {
        gate = _gate;
    }

    function _initializePosition(OrderInfo.PerpPosition memory perpPosition, uint256 _entryPrice) internal {
        OrderInfo.PositionInfo memory position = OrderInfo.PositionInfo({
            isLong: perpPosition.isLong,
            trader: perpPosition.trader,
            initialAmount: perpPosition.initialAmount,
            amount: perpPosition.amount * perpPosition.leverage,
            market: perpPosition.market,
            collateralToken: perpPosition.collateralToken,
            stopLoss: perpPosition.stopLoss,
            takeProfit: perpPosition.takeProfit,
            limitOrder: perpPosition.limitOrder,
            leverage: perpPosition.leverage,
            liquidationPrice: perpPosition.liquidationPrice,
            entryPrice: _entryPrice
        });

        positionId++;

        positionInfo[positionId] = position;
    }

    function getPositionInfo(uint256 _positionID) public view returns (OrderInfo.PositionInfo memory) {
        return positionInfo[_positionID];
    }

    function _onlyGate() internal {
        require(msg.sender == gate);
    }
}
