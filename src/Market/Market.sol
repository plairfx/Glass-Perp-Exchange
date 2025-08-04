// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OrderInfo} from "../libraries/OrderInfo.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Market {
    AggregatorV3Interface internal dataFeed;
    AggregatorV3Interface internal sequencerUptimeFeed;

    event Test(uint256, uint256);

    using SafeERC20 for IERC20;

    struct userLiquidity {
        uint256 tokenADeposit;
        uint256 tokenBDeposit;
    }

    address gate;
    address orderHandler;
    address public tokenA;
    address public tokenB;
    uint8 decimalTokenA;
    uint8 decimalTokenB;

    uint256 SWAP_FEE = 2e15; // standard 0.05% fee.

    uint256 public longs_opened;
    uint256 public shorts_opened;

    mapping(address _user => userLiquidity) userDeposits;

    modifier onlyGate() {
        _onlyGate();
        _;
    }

    modifier onlyHandler() {
        _onlyHandler();
        _;
    }

    constructor(OrderInfo.MarketInfo memory marketInfo) {
        (gate, orderHandler, tokenA, tokenB) =
            (marketInfo.gate, marketInfo.handler, marketInfo.tokenA, marketInfo.tokenB);
        dataFeed = AggregatorV3Interface(marketInfo.priceOracleFeed);
        // for l2's.
        sequencerUptimeFeed = AggregatorV3Interface(marketInfo.L2Sequencer);
        //////////////////////////////////////////////////
        decimalTokenA = IERC20Metadata(marketInfo.tokenA).decimals();
        decimalTokenB = IERC20Metadata(marketInfo.tokenB).decimals();
    }

    function swapToken(OrderInfo.SwapInfo memory swapInfo) public onlyGate {
        uint256 amountIn = swapInfo.amountOut;
        uint256 priceFeedDecimals = dataFeed.decimals();

        if (decimalTokenA != decimalTokenB && decimalTokenA > priceFeedDecimals) {
            int256 _price = getPrice();

            if (swapInfo.buy) {
                uint256 _amountOut = (amountIn * 1e18) / uint256(_price);

                _buyTokens(swapInfo, _amountOut, amountIn);
            } else {
                uint256 _amountOut = (amountIn * uint256(_price)) / 1e20;
                _sellTokens(swapInfo, _amountOut, amountIn);
            }
        } else if (decimalTokenA == decimalTokenB) {
            int256 _price = getPrice();

            if (swapInfo.buy) {
                uint256 _amount = amountIn * (10 ** (priceFeedDecimals - decimalTokenA));
                uint256 _amountOut = (_amount * 1e8) / uint256(_price);
                _buyTokens(swapInfo, _amountOut, amountIn);
            } else {
                uint256 _amountOut = (amountIn * uint256(_price)) / 1e8 / 100;
                _sellTokens(swapInfo, _amountOut, amountIn);
            }
        } else {
            revert("Unsupported Token Decimal");
        }
    }

    function _buyTokens(OrderInfo.SwapInfo memory swapInfo, uint256 _amountOut, uint256 _amountIn) internal {
        require(_amountOut >= swapInfo.minAmountIn, "Amount is not less than expectedAmountIN");

        uint256 amountInWithFee = _amountIn / 100 ether * (100 ether + SWAP_FEE);
        IERC20(tokenB).transferFrom(swapInfo.receiver, address(this), amountInWithFee);

        IERC20(tokenA).transfer(swapInfo.receiver, _amountOut);
    }

    function _sellTokens(OrderInfo.SwapInfo memory swapInfo, uint256 _amount, uint256 amountFromUser) internal {
        require(_amount >= swapInfo.minAmountIn, "Amount is not less than expectedAmountIN");

        uint256 amountUserWithFee = amountFromUser / 100 ether * (100 ether + SWAP_FEE);
        // so there will be some added fees for the users.
        IERC20(tokenA).transferFrom(swapInfo.receiver, address(this), amountUserWithFee);

        IERC20(tokenB).transfer(swapInfo.receiver, _amount);
    }

    function depositLiquidity(uint256 _amountTokenA, uint256 _amountTokenB, address _sender) public onlyGate {
        require(_amountTokenA > 0 || _amountTokenB > 0, "Deposit should be more than zero!");
        userLiquidity storage userDeposit = userDeposits[_sender];

        if (_amountTokenA != 0 && _amountTokenB != 0) {
            IERC20(tokenA).transferFrom(_sender, address(this), _amountTokenA);
            IERC20(tokenB).transferFrom(_sender, address(this), _amountTokenB);

            userDeposit.tokenADeposit += _amountTokenA;
            userDeposit.tokenBDeposit += _amountTokenB;
        } else if (_amountTokenA != 0) {
            IERC20(tokenA).transferFrom(_sender, address(this), _amountTokenA);
            userDeposit.tokenADeposit += _amountTokenA;
        } else {
            IERC20(tokenB).transferFrom(_sender, address(this), _amountTokenB);
            userDeposit.tokenBDeposit += _amountTokenB;
        }
    }

    function withdrawLiquidity(uint256 _amountTokenA, uint256 _amountTokenB, address _receiver)
        public
        onlyGate
        returns (uint256, uint256)
    {
        require(
            userDeposits[_receiver].tokenADeposit > 0 || userDeposits[_receiver].tokenBDeposit > 0,
            "You have not deposited any liquidity!"
        );
        userLiquidity storage userDeposit = userDeposits[_receiver];

        if (_amountTokenA != 0 && _amountTokenB != 0) {
            IERC20(tokenA).transfer(_receiver, _amountTokenA);
            IERC20(tokenB).transfer(_receiver, _amountTokenB);
            userDeposit.tokenADeposit -= _amountTokenA;
            userDeposit.tokenBDeposit -= _amountTokenB;
        } else if (_amountTokenA != 0) {
            IERC20(tokenA).transfer(_receiver, _amountTokenA);
            userDeposit.tokenADeposit -= _amountTokenA;
        } else {
            IERC20(tokenB).transfer(_receiver, _amountTokenB);
            userDeposit.tokenBDeposit -= _amountTokenB;
        }
    }

    function accomodateLiquidation(
        OrderInfo.PositionInfo memory positionInfo,
        uint256 liquidationFee,
        address _receiver
    ) public onlyHandler {
        uint256 liqFee = liquidationFee / 2;
        emit Test(liqFee, liquidationFee);
        IERC20(positionInfo.collateralToken).transfer(_receiver, liqFee);
        // 50%..
    }

    function getTokenBalances() public view returns (uint256, uint256) {
        return (IERC20(tokenA).balanceOf(address(this)), IERC20(tokenB).balanceOf(address(this)));
    }

    function getPrice() internal view returns (int256) {
        // if the contract is deployed on a L2.
        if (address(sequencerUptimeFeed) != address(0x0)) {
            (
                /*uint80 roundID*/
                ,
                int256 answer,
                uint256 startedAt,
                // /*uint256 updatedAt*/
                ,
                /*uint80 answeredInRound*/
            ) = sequencerUptimeFeed.latestRoundData();

            if (answer == 1) {
                revert("L2 sequencer is down");
            }
        }
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            dataFeed.latestRoundData();

        // if (updatedAt < block.timestamp - 60 * 60) {
        //     revert("stale price feed");
        // }

        // ^ Enable this only on live blockchains. etc.

        return answer;
    }

    function getDecimals() public view returns (uint8, uint8) {
        return (decimalTokenA, decimalTokenB);
    }

    function convertTokenAToUSDToken() public view returns (uint256) {}

    function getCurrentPrice() public view returns (int256) {
        return getPrice();
    }

    function _onlyGate() internal {
        require(msg.sender == gate);
    }

    function _onlyHandler() internal {
        require(msg.sender == orderHandler, "not the handler");
    }
}
