// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(uint8 _decimals) ERC20("ERC20", "ERC20") {
        deci = _decimals;
    }

    uint8 deci;

    function decimals() public view override returns (uint8) {
        return deci;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
