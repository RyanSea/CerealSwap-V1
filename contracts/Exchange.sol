//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

import {Factory} from "./Factory.sol";

contract Exchange is ERC20 {

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
                                            
    ERC20 public immutable erc20;
    address public factory;

    constructor(ERC20 _erc20) ERC20(
        string(abi.encodePacked("CerealSwap-", _erc20.name(),"-V1")),
        string(abi.encodePacked("yum", _erc20.symbol(),"-V1")),
        18
    ){
        require(address(_erc20) != address(0), "INVALID_ADDRESS!");
        erc20 = _erc20;
        factory = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                                STAKING
    //////////////////////////////////////////////////////////////*/

    function addLiquidity(uint amount) public payable returns (uint liquidity) {
        uint tokensIn;

        // Check if there is no existing liquidty 
        if (totalSupply == 0 ) {
            tokensIn = amount;

            liquidity = msg.value;
        } else {
            // Assign pre-existing ETH reserve
            uint ethReserve = address(this).balance - msg.value;

            // Calculate the amount of tokens to be staked based on current reserves and incoming ETH
            tokensIn = msg.value * erc20Reserve() / ethReserve;

            // Calculate amount of LP tokens incoming stake is worth
            liquidity = msg.value * totalSupply / ethReserve;
        }
        // Require amount of tokens sent is equal or greater than the amount of tokens accepted
        require(amount >= tokensIn, "INSUFFICIENT_AMOUNT!");

        erc20.transferFrom(msg.sender, address(this), tokensIn);

        _mint(msg.sender, liquidity);
    }

    /// @notice Redeem
    /// @param amount Amount of LP tokens used to redeem
    function removeLiquidity(uint amount) public returns (uint eth, uint _erc20) {
        // Require non-zero amount of LP tokens
        require(amount > 0, "INSUFFICIENT_LP_TOKENS!");

        // Calculate ETH to be redeemed
        eth = amount * address(this).balance / totalSupply; 

        // Calulate ERC-20 tokens to be redeemed
        _erc20 = amount * erc20Reserve() / totalSupply; 

        _burn(msg.sender, amount);

        payable(msg.sender).transfer(eth);

        erc20.transfer(msg.sender, _erc20);
    }

    /*///////////////////////////////////////////////////////////////
                                SWAPPING
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap ETH for ERC-20
    function swapEth(uint minOut, address to) public payable {
        uint erc20Out = tokensOut(
            msg.value, 
            address(this).balance - msg.value, 
            erc20Reserve()
        );

        require(minOut >= erc20Out, "MINIMUM_TOO_LOW!");

        erc20.transfer(to, erc20Out);
    }

    /// @notice Swap ERC-20 for ETH
    function swapErc20(
        uint erc20in, 
        uint minOut, 
        address to
    ) public {
        uint ethOut = tokensOut(
            erc20in, 
            erc20Reserve(), 
            address(this).balance
        );

        require(minOut >= ethOut, "MINIMUM_TOO_LOW!");

        erc20.transferFrom(msg.sender, address(this), erc20in);

        payable(to).transfer(ethOut);
    }

    /// @notice Swap between 2 ERC-20's
    function swapErc20toErc20(
        uint erc20in,
        uint minOut,
        address erc20out,
        address to
    ) public {
        uint eth = tokensOut(
            erc20in, 
            erc20Reserve(), 
            address(this).balance
        );

        address _exchangeAddress = Factory(factory).exchange(erc20out);

        require(_exchangeAddress != address(this) && _exchangeAddress != address(0), "INVALID_EXCHANGE!");

        Exchange _exchange = Exchange(_exchangeAddress);

        require(_exchange.validMin(eth, minOut), "MINIMUM_TOO_LOW!");

        erc20.transferFrom(msg.sender, address(this), erc20in);

        _exchange.swapEth(minOut, to);
    }

    /*///////////////////////////////////////////////////////////////
                               ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate amount of tokens to be swapped out of vault
    /// @param inAmount Number of tokens user is swapping
    /// @param inReserve Reserve of tokens user is swapping
    /// @param outReserve Reserve of tokens user wants to receive 
    function tokensOut(
        uint inAmount, 
        uint inReserve, 
        uint outReserve
    ) internal pure returns (uint amount) {
        // Ensure reserves aren't empty
        require(inReserve > 0 && outReserve > 0, "INSUFFICIENT_RESERVES!");

        // Tokens after 1% LP fee (99%)
        uint tokensIn = inAmount * 99;
        
        // △y = (y * (△x * 99)) / ((x * 100) + (△x * 99))
        amount = outReserve * tokensIn / ((inReserve * 100) + tokensIn);
    }

    /// @notice Checks if minOut is high enough when another exchange is calling, for erc20 to erc20 swaps
    function validMin(uint ethIn, uint minOut) public view returns (bool valid) {
        uint out = tokensOut(
            ethIn, 
            address(this).balance,
            erc20Reserve()
        );

        valid = minOut >= out;
    }

    /// @notice Reserve of ERC-20
    function erc20Reserve() public view returns (uint reserve) {
        reserve = erc20.balanceOf(address(this));
    }

}