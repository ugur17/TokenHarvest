// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./HarvestToken.sol";
import "./StableTestCoin.sol";

error AMM__InsufficientTokenAmount();
error AMM__InsufficientLpToken();
error AMM__ProblemWithReserveBalances();

contract AMM is ERC20, ERC20Burnable {
    HarvestToken hrvToken;
    StableTestCoin stcToken;

    constructor(
        address harvestTokenContractAddress,
        address stcTokenContractAddress
    ) ERC20("LiquidityProvider", "LP") {
        hrvToken = HarvestToken(harvestTokenContractAddress);
        stcToken = StableTestCoin(stcTokenContractAddress);
    }

    function addLiquidity(
        uint256 amountOfStcToken,
        uint256 amountOfHrvToken
    ) public returns (uint256) {
        uint256 lpTokensToMint;
        uint256 stcReserveBalance = getStcTokenReserve();
        uint256 hrvReserveBalance = getHrvTokenReserve();

        // if there is no any liquidty in the pool, then we will initialize the price
        if (hrvReserveBalance == 0) {
            // there is no check for the minimum required token amount
            // because we will determine the price here if this is the first liquidity
            stcToken.transferFrom(msg.sender, address(this), amountOfStcToken);
            hrvToken.transferFrom(msg.sender, address(this), amountOfHrvToken);

            // amount of lp tokens will be minted will be equal to the amount of stable coin which user sent
            lpTokensToMint = amountOfStcToken;

            // mint the lp token and send to the user who adds the liquidity
            _mint(msg.sender, lpTokensToMint);

            return lpTokensToMint;
        }
        // If there is already liquidity in the pool:

        // (sent stable coin / total stable coin reserve) should be equal to (will be sent hrv token / total hrv reserve)
        uint256 minHrvTokenAmountRequired = (amountOfStcToken * hrvReserveBalance) /
            stcReserveBalance;

        // it will revert also sent ethers to the provider's address
        if (amountOfHrvToken < minHrvTokenAmountRequired) {
            revert AMM__InsufficientTokenAmount();
        }

        // if there is no problem with the provided amount, then send the hrv tokens to the pool
        stcToken.transferFrom(msg.sender, address(this), amountOfStcToken);
        hrvToken.transferFrom(msg.sender, address(this), minHrvTokenAmountRequired);

        // (sent stable coin / total stable coin reserve) should be equal to (will be minted lp tokens / total lp token supply)
        lpTokensToMint = (totalSupply() * amountOfStcToken) / stcReserveBalance;

        // mint the lp token and send to the user who adds liquidity
        _mint(msg.sender, lpTokensToMint);

        return lpTokensToMint;
    }

    function removeLiquidity(uint256 amountOfLPTokens) public returns (uint256, uint256) {
        if (amountOfLPTokens <= 0) {
            revert AMM__InsufficientLpToken();
        }

        uint256 stcReserveBalance = getStcTokenReserve();
        uint256 hrvReserveBalance = getHrvTokenReserve();
        uint256 lpTokenTotalSupply = totalSupply();

        // (amountOfLPTokens / total lp token supply) should be equals to
        // (stc token will be withdrawn / total stc reserve balance in the pool)
        uint256 stcToReturn = (stcReserveBalance * amountOfLPTokens) / lpTokenTotalSupply;
        // (amountOfLPTokens / total lp token supply) should be equals to
        // (hrv token will be withdrawn / total hrv reserve balance in the pool)
        uint256 hrvToReturn = (hrvReserveBalance * amountOfLPTokens) / lpTokenTotalSupply;

        // Burn the LP tokens from the user, and transfer the stc and hrv tokens to the user
        _burn(msg.sender, amountOfLPTokens);
        stcToken.transfer(msg.sender, stcToReturn);
        hrvToken.transfer(msg.sender, hrvToReturn);

        return (stcToReturn, hrvToReturn);
    }

    function stcToHrvSwap(uint256 inputStcTokenAmount) public {
        uint256 stcTokenReserve = getStcTokenReserve(); // input reserve here
        uint256 hrvReserveBalance = getHrvTokenReserve(); // output reserve here
        uint256 hrvTokensToReceive = calculateOutputAmountFromSwap(
            inputStcTokenAmount,
            stcTokenReserve,
            hrvReserveBalance
        );

        // send input amount of stc token from user to the contract
        stcToken.transferFrom(msg.sender, address(this), inputStcTokenAmount);

        // send calculated amount of hrv token from contract to the user
        hrvToken.transfer(msg.sender, hrvTokensToReceive);
    }

    function hrvToStcSwap(uint256 inputHrvTokenAmount) public {
        uint256 hrvReserveBalance = getHrvTokenReserve(); // input reserve here
        uint256 stcTokenReserve = getStcTokenReserve(); // output reserve here
        uint256 stcTokensToReceive = calculateOutputAmountFromSwap(
            inputHrvTokenAmount,
            hrvReserveBalance,
            stcTokenReserve
        );

        // send input amount of hrv token from user to the contract
        hrvToken.transferFrom(msg.sender, address(this), inputHrvTokenAmount);

        // send calculated amount of stc token from contract to the user
        stcToken.transfer(msg.sender, stcTokensToReceive);
    }

    // General rule: (x*y = k), if one of x and y changes,
    // then k will be constant and the other parameter will be changed according to this rule
    function calculateOutputAmountFromSwap(
        uint256 inputAmount,
        uint256 inputReserveBalance,
        uint256 outputReserveBalance
    ) public pure returns (uint256) {
        if (inputReserveBalance <= 0 || outputReserveBalance <= 0) {
            revert AMM__ProblemWithReserveBalances();
        }

        // There is 1% fee for using of the exchange
        uint256 inputAmountWithFee = inputAmount * 99;

        /*
            Let's say: 
            x: inputReserveBalance
            y: outputReserveBalance
            z: inputAmount
            k: (x * y) constant
            Then, when we try to swap 'z' amount of input token;
            k = (x + z) * (y - dy)  ---------> dy means output amount which we are trying to calculate
            dy = y - (k / (x + z))  ---------> if we substitute k with (x * y)
            dy = (y * z) / (x + z)
            Then, we will charge 1% fee. So;
            dy = (y * (99z / 100)) / (x + (99z / 100)) ----------> If we rewrite the equation
            dy = (99 * z * y) / ((100 * x) + (99 * z))
            Here, (99 * z) means "inputAmountWithFee" as you can see above.
            To simplify the equation:
            dy = (inputAmountWithFee * outputReserveBalance) / ( (100 * inputReserveBalance) + inputAmountWithFee )
        */
        uint256 numerator = inputAmountWithFee * outputReserveBalance;
        uint256 denominator = (100 * inputReserveBalance) + inputAmountWithFee;

        return numerator / denominator;
    }

    function getHrvTokenReserve() public view returns (uint256) {
        return hrvToken.balanceOf(address(this));
    }

    function getStcTokenReserve() public view returns (uint256) {
        return stcToken.balanceOf(address(this));
    }
}
