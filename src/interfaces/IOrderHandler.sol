// SPDX-License-Identifier: MIT

import {OrderInfo} from "../libraries/OrderInfo.sol";

pragma solidity 0.8.30;

interface IOrderHandler {
    function longOrShort(OrderInfo.PerpPosition memory perpPosition) external;
    function liquidateUser(uint256 _positionId, address market, address _liquidator) external;
    function closePosition(uint256 _positionId, address _receiver, address market) external;
}
