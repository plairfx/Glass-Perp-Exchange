// SPDX-License-Identifier: MIT
import {Market, MarketFactory, OrderInfo} from "../src/Market/MarketFactory.sol";
import {Gate} from "../src/Gate.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";
import {OrderHandler} from "../src/OrderHandler.sol";

pragma solidity 0.8.30;

contract GlassTest is Test {
    Gate public gate;
    Market public market;
    MarketFactory public marketF;
    MockV3Aggregator public priceOracle;
    OrderHandler public orderHandler;

    address liquidator = makeAddr("liquidator");
    address owner = makeAddr("owner");
    address LP = makeAddr("LP");
    address alice = makeAddr("alice");

    address WETHUSDC;
    address WBTCUSDC;

    // erc20 tokens..
    ERC20Mock public WBTC;
    ERC20Mock public WETH;
    ERC20Mock public USDC;

    function setUp() external {
        /// WBTC..
        WBTC = new ERC20Mock(6);
        WETH = new ERC20Mock(18);
        USDC = new ERC20Mock(6);
        priceOracle = new MockV3Aggregator(8, 100000e8);

        WBTC.mint(LP, 10e6); // 10 BTC
        USDC.mint(LP, 100e6); // 100 USDC
        WETH.mint(LP, 10e18);

        // creating the market....
        marketF = new MarketFactory(owner);
        orderHandler = new OrderHandler(owner);
        gate = new Gate(address(marketF), address(orderHandler));

        vm.startPrank(owner);
        orderHandler.setGate(address(gate));
    }

    function test_OwnerCanDeployMarket() public {
        OrderInfo.MarketInfo memory Params = OrderInfo.MarketInfo({
            tokenA: address(WETH),
            tokenB: address(USDC),
            gate: address(gate),
            priceOracleFeed: address(priceOracle),
            L2Sequencer: address(0x0),
            handler: address(orderHandler)
        });

        vm.startPrank(owner);
        address market = marketF.deployMarket(Params);
        assertNotEq(market, address(0x0));

        vm.expectRevert();
        Market(market).depositLiquidity(1, 1, address(0x0));
    }

    modifier marketCreated() {
        OrderInfo.MarketInfo memory Params = OrderInfo.MarketInfo({
            tokenA: address(WBTC),
            tokenB: address(USDC),
            gate: address(gate),
            priceOracleFeed: address(priceOracle),
            L2Sequencer: address(0x0),
            handler: address(orderHandler)
        });
        vm.startPrank(owner);
        WBTCUSDC = marketF.deployMarket(Params);
        _;
    }

    modifier mCandLiquidityDeposited() {
        OrderInfo.MarketInfo memory Params = OrderInfo.MarketInfo({
            tokenA: address(WBTC),
            tokenB: address(USDC),
            gate: address(gate),
            priceOracleFeed: address(priceOracle),
            L2Sequencer: address(0x0),
            handler: address(orderHandler)
        });
        vm.startPrank(owner);
        WBTCUSDC = marketF.deployMarket(Params);
        vm.startPrank(LP);

        WBTC.approve(address(WBTCUSDC), 1e6);
        USDC.approve(address(WBTCUSDC), 10e6);
        gate.depositLiquidity(1e6, 10e6, WBTCUSDC);

        OrderInfo.MarketInfo memory Params2 = OrderInfo.MarketInfo({
            tokenA: address(WETH),
            tokenB: address(USDC),
            gate: address(gate),
            priceOracleFeed: address(priceOracle),
            L2Sequencer: address(0x0),
            handler: address(orderHandler)
        });
        vm.startPrank(owner);
        WETHUSDC = marketF.deployMarket(Params2);
        vm.startPrank(LP);

        WETH.approve(address(WETHUSDC), 1e18);
        USDC.approve(address(WETHUSDC), 10e6);
        gate.depositLiquidity(1e18, 10e6, WETHUSDC);

        _;
    }

    function test_OnlyGateCanCallMarketFunctions() public marketCreated {
        vm.startPrank(alice);
        vm.expectRevert();
        Market(WBTCUSDC).withdrawLiquidity(1, 1, alice);
        vm.expectRevert();
        Market(WBTCUSDC).depositLiquidity(1, 1, alice);
        vm.expectRevert();

        OrderInfo.SwapInfo memory Params = OrderInfo.SwapInfo({
            minAmountIn: 1,
            amountOut: 10,
            market: WBTCUSDC,
            receiver: alice,
            orgChain: 1,
            destChain: 1,
            buy: true
        });

        Market(WBTCUSDC).swapToken(Params);
    }

    function test_DepositAndWithdrawLiquidityWorks() public marketCreated {
        // cannot call a  random non whitelisted address/market.

        address fakeMarket = makeAddr("fakeMarket");
        vm.expectRevert("Market is not whitelisted");
        gate.depositLiquidity(1e16, 10e6, fakeMarket);

        uint256 balanceUSDCBeforeDeposit = USDC.balanceOf(LP);
        uint256 balanceBTCCBeforeDeposit = WBTC.balanceOf(LP);
        vm.startPrank(LP);

        WBTC.approve(address(WBTCUSDC), 1e6);
        USDC.approve(address(WBTCUSDC), 10e6);
        gate.depositLiquidity(1e6, 10e6, WBTCUSDC);

        assertEq(balanceBTCCBeforeDeposit - 1e6, WBTC.balanceOf(LP));
        assertEq(balanceUSDCBeforeDeposit - 10e6, USDC.balanceOf(LP));

        (uint256 WBTCbalance, uint256 USDCBalance) = Market(WBTCUSDC).getTokenBalances();

        assertEq(WBTCbalance, 1e6);
        assertEq(USDCBalance, 10e6);

        // Withdrwaing liquidity
        vm.expectRevert("Market is not whitelisted");
        gate.withdrawLiquidity(1e16, 10e6, fakeMarket);

        uint256 balanceUSDCBeforeWithdraw = USDC.balanceOf(LP);
        uint256 balanceBTCCBeforeWithdraw = WBTC.balanceOf(LP);

        gate.withdrawLiquidity(1e6, 10e6, WBTCUSDC);

        (uint256 WBTCbalanceWithdraw, uint256 USDCBalanceWithdraw) = Market(WBTCUSDC).getTokenBalances();

        assertEq(WBTCbalanceWithdraw, 0);
        assertEq(USDCBalanceWithdraw, 0);

        assertEq(balanceBTCCBeforeWithdraw + 1e6, WBTC.balanceOf(LP));
        assertEq(balanceUSDCBeforeWithdraw + 10e6, USDC.balanceOf(LP));
    }

    function test_buyWBTCsWorksCorrectly() public mCandLiquidityDeposited {
        USDC.mint(alice, 10e6);
        // update the price.. to 120k per btc.
        priceOracle.updateAnswer(120000e8);
        vm.startPrank(alice);

        OrderInfo.SwapInfo memory Params = OrderInfo.SwapInfo({
            minAmountIn: 8000,
            amountOut: 10e6,
            market: WBTCUSDC,
            receiver: alice,
            orgChain: 1,
            destChain: 1,
            buy: true
        });

        USDC.approve(address(WBTCUSDC), 10e6);

        gate.swapTokens(Params);
        // 10 USDC / 120k BTC =
        assertEq(WBTC.balanceOf(alice), 8333);
    }

    function test_SellUSDCSameDecimalWorks() public mCandLiquidityDeposited {
        WBTC.mint(alice, 8333);
        // update the price.. to 120k per btc.
        priceOracle.updateAnswer(120000e8);
        vm.startPrank(alice);

        OrderInfo.SwapInfo memory Params = OrderInfo.SwapInfo({
            minAmountIn: 9e6,
            amountOut: 8333,
            market: WBTCUSDC,
            receiver: alice,
            orgChain: 1,
            destChain: 1,
            buy: false
        });

        WBTC.approve(address(WBTCUSDC), 8333);

        gate.swapTokens(Params);
        // this happens due solidity integere problem,
        // fixedPointMath from solady should fix this.
        assertEq(USDC.balanceOf(alice), 9999600);
    }

    // fix this issue with the uuh
    function test_BuyWETHWorksCorrectly() public mCandLiquidityDeposited {
        USDC.mint(alice, 10e6);
        // update the price.. to 120k per btc.
        priceOracle.updateAnswer(4000e8);
        vm.startPrank(alice);

        OrderInfo.SwapInfo memory Params = OrderInfo.SwapInfo({
            minAmountIn: 2.5e13,
            amountOut: 10e6,
            market: WETHUSDC,
            receiver: alice,
            orgChain: 1,
            destChain: 1,
            buy: true
        });

        USDC.approve(address(WETHUSDC), 10e6);

        gate.swapTokens(Params);

        assertGt(WETH.balanceOf(alice), 2.4e13);
        // lets do the maths..
    }

    function test_BuyUSDCWorkCorrectlyWithWETH() public mCandLiquidityDeposited {
        WETH.mint(alice, 1 ether);
        // update the price.. to 120k per btc.
        priceOracle.updateAnswer(4000e8);
        vm.startPrank(alice);

        OrderInfo.SwapInfo memory Params = OrderInfo.SwapInfo({
            minAmountIn: 9e6,
            amountOut: 2.5e15,
            market: WETHUSDC,
            receiver: alice,
            orgChain: 1,
            destChain: 1,
            buy: false
        });

        WETH.approve(address(WETHUSDC), 2.5e15);

        gate.swapTokens(Params);
        assertGt(USDC.balanceOf(alice), 9999000);
    }

    function test_LongPositionWorksOutProfit() public mCandLiquidityDeposited {
        // for this test we will use orderhandler as the pool
        //
        WETH.mint(alice, 1 ether);
        WETH.mint(address(orderHandler), 10 ether);
        uint256 balanceBefore = WETH.balanceOf(alice);
        uint256 intialAmount = 1e17; // 0.1 ether;
        uint256 leverage = 1;
        uint256 amount = intialAmount * leverage;

        priceOracle.updateAnswer(4000e8);

        OrderInfo.PerpPosition memory Params = OrderInfo.PerpPosition({
            isLong: true,
            trader: alice,
            initialAmount: intialAmount,
            amount: amount,
            market: WETHUSDC,
            collateralToken: address(WETH),
            stopLoss: 1,
            takeProfit: 0,
            limitOrder: 0,
            leverage: 1,
            liquidationPrice: 0
        });

        vm.startPrank(alice);

        WETH.approve(address(orderHandler), intialAmount);

        gate.longOrShort(Params);

        OrderInfo.PositionInfo memory Params2 = orderHandler.getPositionInfo(1);

        // assertEq(Params2.entryPrice, 4004e8);

        priceOracle.updateAnswer(5000e8);

        uint256 outcome = 5000e8 - 4040e8;
        uint256 expectedProfitInPercentage = outcome * 1 ether / 4040e8;

        uint256 profit = (Params2.amount * expectedProfitInPercentage) / 1e18;
        console.log(profit);

        uint256 amountToReceive = profit + intialAmount;

        gate.closePosition(1, WETHUSDC);

        console.log(balanceBefore, WETH.balanceOf(alice));

        assertGt(WETH.balanceOf(alice), balanceBefore + profit);

        ////
        uint256 balanceBeforeLoss = WETH.balanceOf(alice);

        WETH.approve(address(orderHandler), intialAmount);

        gate.longOrShort(Params);

        priceOracle.updateAnswer(4000e8);
        gate.closePosition(2, WETHUSDC);

        assertGt(balanceBeforeLoss, WETH.balanceOf(alice));
    }

    function test_ShortPositionWorksOut() public mCandLiquidityDeposited {
        // SHORT PROIT

        USDC.mint(alice, 10e6);
        USDC.mint(address(orderHandler), 1000e6);
        uint256 balanceBefore = USDC.balanceOf(alice);
        uint256 intialAmount = 10e6; // 10 USDC
        uint256 leverage = 1;
        uint256 amount = intialAmount * leverage;

        priceOracle.updateAnswer(4000e8);

        OrderInfo.PerpPosition memory Params = OrderInfo.PerpPosition({
            isLong: false,
            trader: alice,
            initialAmount: intialAmount,
            amount: amount,
            market: WETHUSDC,
            collateralToken: address(USDC),
            stopLoss: 1,
            takeProfit: 0,
            limitOrder: 0,
            leverage: 1,
            liquidationPrice: 0
        });

        vm.startPrank(alice);

        USDC.approve(address(orderHandler), intialAmount);

        gate.longOrShort(Params);

        priceOracle.updateAnswer(3000e8);

        gate.closePosition(1, WETHUSDC);

        assertGt(USDC.balanceOf(alice), balanceBefore);

        // SHORT LOSS!

        uint256 balanceBeforeLoss = USDC.balanceOf(alice);

        USDC.approve(address(orderHandler), intialAmount);

        OrderInfo.PositionInfo memory Params2 = orderHandler.getPositionInfo(2);

        priceOracle.updateAnswer(3000e8);

        gate.longOrShort(Params);

        priceOracle.updateAnswer(4000e8);

        gate.closePosition(2, WETHUSDC);

        assertGt(balanceBeforeLoss, USDC.balanceOf(alice));
    }

    function test_LiquidatingUserWorks() public mCandLiquidityDeposited {
        WETH.mint(alice, 1 ether);
        WETH.mint(WETHUSDC, 1000 ether);
        vm.startPrank(alice);

        uint256 balanceBefore = WETH.balanceOf(alice);
        uint256 intialAmount = 1e17; // 0.1 ether;
        uint256 leverage = 10;
        uint256 amount = intialAmount * leverage;

        OrderInfo.PerpPosition memory Params = OrderInfo.PerpPosition({
            isLong: true,
            trader: alice,
            initialAmount: intialAmount,
            amount: amount,
            market: WETHUSDC,
            collateralToken: address(WETH),
            stopLoss: 1,
            takeProfit: 0,
            limitOrder: 0,
            leverage: 50,
            liquidationPrice: 0
        });

        priceOracle.updateAnswer(5000e8);

        WETH.approve(address(orderHandler), intialAmount);

        gate.longOrShort(Params);

        priceOracle.updateAnswer(4910e8);
        // not liquidatable
        uint256 balanceBeforeL = WETH.balanceOf(liquidator);
        vm.startPrank(liquidator);
        vm.expectRevert("User cannot be liquidated yet!");
        gate.liquidateUser(1, WETHUSDC);
        priceOracle.updateAnswer(4890e8);
        gate.liquidateUser(1, WETHUSDC);

        assertGt(WETH.balanceOf(liquidator), balanceBeforeL);
    }
}
