//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Factory.sol";

contract Exchange is ERC20 {

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
                                            
    ERC20 public token;
    address public factory;

    constructor(ERC20 _token) 
        ERC20(
            string(abi.encodePacked("CerealSwap LP-", _token.name())), 
            string(abi.encodePacked("yum", _token.symbol()))
        ){
        require(address(_token) != address(0), "INVALID_ADDRESS");
        token = _token;
        factory = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice ERC-20 token Reserve
    function tokenReserve() public view returns (uint reserve) {
        reserve = token.balanceOf(address(this));
    }

    /// @notice Cost of Token A for token B
    /// @param inReserve Token that user is selling
    /// @param outReserve Token that user is buying
    function price(uint inReserve, uint outReserve) public pure returns (uint _price) {
        require(inReserve > 0 && outReserve > 0, "INVALID_RESERVES");
        _price = inReserve * 1000 / outReserve;
    }

    /// @notice The amount of Tokens A user receives when swapping for Token B
    /// @param amountIn The amount of Token A user is swapping
    /// @param inTokenReserve Reserves of Token A
    /// @param outTokenReserve Reserves for Token B
    function amountOut(
        uint amountIn,
        uint inTokenReserve,
        uint outTokenReserve
    ) private pure returns (uint amount) {
        require(inTokenReserve > 0 && outTokenReserve > 0, "INSUFFICIENT_RESERVES");
        // multiply amountIn by 100 - [fee percent], where 100 - 1 is a 1% fee
        uint inAfterFee = amountIn * 99;
        // △y = ( Reserve-y * (△x * 99) ) / ( (Reserve-x * 100) + (△x * 99) )
        amount = outTokenReserve * inAfterFee / ( (inTokenReserve * 100) + inAfterFee );
    }

    /// @notice Amount of tokens bought for ethIn
    /// @param ethIn Amount of eth user is swapping for tokens
    function tokenAmountOut(uint ethIn) public view returns (uint tokenOut) {
        require(ethIn > 0, "INSUFFICIENT_ETH");
        tokenOut = amountOut(ethIn, address(this).balance, tokenReserve());
    }

    /// @notice Amount of eth bought for tokenIn
    /// @param tokenIn Amount of tokens user is swapping for eth
    function ethAmountOut(uint tokenIn) public view returns (uint ethOut) {
        require(tokenIn > 0, "INSUFFICIENT_TOKEN");
        ethOut = amountOut(tokenIn, tokenReserve(), address(this).balance);
    }

    /*///////////////////////////////////////////////////////////////
                            DEPOSIT/WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Stake tokens to reserve
    /// @param amount Amount of tokens staked
    function addLiquidity(uint amount) public payable returns (uint liquidity) {
        // If ratio not set:
        if (tokenReserve() == 0){
            // Transfer amount of tokens
            token.transferFrom(msg.sender, address(this), amount);

            // Mint LP tokens based on eth sent
            liquidity = msg.value;
            _mint(msg.sender, liquidity);
        } else {
            // Calculate tokenAmount based on new eth staked and current ratio of reserves 
            uint ethReserve = address(this).balance - msg.value;
            uint tokenAmount = msg.value * tokenReserve() / ethReserve;

            require(amount >= tokenAmount, "INSUFFICIENT_AMOUNT");

            token.transferFrom(msg.sender, address(this), tokenAmount);

            // Mint LP tokens
            liquidity = msg.value * totalSupply() /  ethReserve; 
            _mint(msg.sender, liquidity);                                                                      
        }
    }

    /// @notice Unstake tokens from reserve
    /// @param amount Amount of LP tokens to burn
    function removeLiquidity(uint amount) public returns (uint eth, uint tokens) {
        // Require non zero amount
        require(amount > 0, "NO_TOKENS");
        // Culculate eth & tokens based on the amount of LP tokens being burned divided by LP tokens' totalSupply
        eth = amount * address(this).balance / totalSupply(); 
        tokens = amount * tokenReserve() / totalSupply(); 
        

        // Burn amount of LP tokens
        _burn(msg.sender, amount); //

        // Distribute eth and token to LP
        payable(msg.sender).transfer(eth);
        token.transfer(msg.sender, tokens);
    }

    /*///////////////////////////////////////////////////////////////
                                SWAPPING
    //////////////////////////////////////////////////////////////*/

    /// @notice Interface to swap eth to token
    /// @param minOut Minimum tokens user expects to receive 
    /// @param to Address to receive token
    function ethToToken(uint minOut, address to) internal {
        // Get amount of tokens user will receive
        uint tokensOut = amountOut(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve()
        );

        require(tokensOut >= minOut, "MINIMUM_TOO_LOW");

        token.transfer(msg.sender, tokensOut);
    }
    /// @notice Swap eth to token
    function swapEth(uint minOut) public payable {
        ethToToken(minOut, msg.sender);
    }

    /// @notice Swap eth to token, sent to alternate address
    function transferTokenFromEth(uint minOut, address to) public payable {
        ethToToken(minOut, to);
    }

    /// @notice Swap token to eth
    /// @param tokensIn Tokens user is swapping
    /// @param minOut Minimum amount of eth user expects to receive
    function swapToken(uint tokensIn, uint minOut) public {
        //Get amount of eth user will receive
        uint ethOut = amountOut(tokensIn, tokenReserve(), address(this).balance);

        require(ethOut >= minOut, "MINIMUM_TOO_LOW");

        token.transferFrom(msg.sender, address(this), tokensIn);
        payable(msg.sender).transfer(ethOut);
    }

    /// @notice Swap token1 to token2
    /// @param tokensIn Amountof token1 user is swapping
    /// @param minOut Minimum amount of token2 user expects to receive 
    /// @param tokenOut Address of token2
    function swapTokenToToken(
        uint tokensIn, 
        uint minOut, 
        address tokenOut
    ) public {
        // Get exchange address from Factory and require that it's not this address and not the 0 address
        address exchangeAddress = Factory(factory).exchange(tokenOut);
        require(exchangeAddress != address(this) && exchangeAddress != address(0), "INVALID_TOKEN_ADDRESS");

        // Get amount of eth user's tokens will be converted to 
        // and transfer tokens to contract
        uint eth = amountOut(tokensIn, tokenReserve(), address(this).balance);
        token.transferFrom(msg.sender, address(this), tokensIn);
        
        Exchange(exchangeAddress).transferTokenFromEth{value: eth}(minOut, msg.sender);
    }

}