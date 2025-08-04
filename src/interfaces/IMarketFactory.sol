// SPDX-License-Identifier : MIT

pragma solidity 0.8.30;

interface IMarketFactory {
    function getApprovedMarket(address market) external view returns (bool);
}
