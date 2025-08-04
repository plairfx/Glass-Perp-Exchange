## Glass Perpetual Exchange

This project was made during the Unite defi, this perp exchange project was inspired by the likes of GMX, but with a twist by adding a liquidation feature that anyone can execute and profit from the liquidation depending on the initial collateral size.


## Usage

### Build


```shell
$ forge install
```

```shell
$ forge build
```

```shell
$ forge test
```

## Contract Structure


#### Gate.sol
Entrypoint for the protocol, which directs all the actions made by the user to the specfiic contract,
you can essentially compare this to a router.


#### Market.sol
The main contract of this protocol which is used for swaps and deposting/withdrawing liqudity.


#### OrderHandler.sol
This handles the perputual trades (long or shorts), you can open your position with your chosen leverage/depositAmount and close it or and liquidate positions you deem to be profitable for you.

