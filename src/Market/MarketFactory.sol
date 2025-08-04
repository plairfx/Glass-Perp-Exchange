// SPDX-License-Identifier: MIT

import {Market} from "./Market.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OrderInfo} from "../libraries/OrderInfo.sol";

pragma solidity 0.8.30;

contract MarketFactory is Ownable {
    mapping(address market => bool approved) approvedMarkets;

    constructor(address _gov) Ownable(_gov) {}

    function deployMarket(OrderInfo.MarketInfo memory marketInfo) public onlyOwner returns (address) {
        Market market;

        market = new Market(marketInfo);

        approvedMarkets[(address(market))] = true;

        return address(market);
    }

    function getApprovedMarket(address _market) public view returns (bool) {
        return approvedMarkets[_market];
    }
}
