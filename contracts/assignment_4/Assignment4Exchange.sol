// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "hardhat/console.sol";

// Import BaseAssignment.sol
import "../BaseAssignment.sol";

interface IRegistry {
    function getExchange(address _exchangeAddress) external returns (address);
}

contract Assignment4Exchange is ERC20, BaseAssignment {
    address public tokenAddress;
    address public registryAddress;

    event TokenBought(
        address indexed buyer,
        uint256 indexed ethSold,
        uint256 indexed tokensBought
    );
    event EthBought(
        address indexed buyer,
        uint256 indexed ethBought,
        uint256 indexed tokensSold
    );
    event LiquidityAdded(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    constructor(address _token, address _validator, address _registry)
        payable
        ERC20("Assignment 4 Exchange", "A2E")
        BaseAssignment(_validator)
    {
        // Official validator: 0xaBfE6D21E69eEe5eB228E007c23eeF45c5BB539e
        require(_token != address(0), "invalid token address");
        tokenAddress = _token;
        // Official registry: 0xCd7368D363d30469bf70A7135578716988FC1BdD
        registryAddress = _registry;
    }

    function getTokenAddress() public view returns (address) {
        return tokenAddress;
    }

    function addLiquidity(uint256 _tokenAmount)
        public
        payable
        returns (uint256)
    {
        uint256 tokenAmount;
        uint256 liquidity;
        uint256 ethBalance = address(this).balance;
        uint256 tokenReserve = getReserve();

        // console.log('****addLiquidity');

        IERC20 token = IERC20(tokenAddress);

        if (tokenReserve == 0) {
            // console.log('****tokenReserve 0'); 

            liquidity = ethBalance;
            tokenAmount = _tokenAmount;
        }
        else {
            // console.log('****tokenReserve > 0');

            uint256 ethReserve = ethBalance - msg.value;
            tokenAmount = (msg.value * tokenReserve) / ethReserve;
            require(_tokenAmount >= tokenAmount, "insufficient token amount");

            // Calculate the liquidity
            liquidity = (totalSupply() * msg.value) / ethReserve;
        }

        // Transfer the tokens to the exchange
        token.transferFrom(msg.sender, address(this), tokenAmount);
        _mint(msg.sender, liquidity);

        // Event.
        emit LiquidityAdded(msg.sender, msg.value, _tokenAmount);

        return liquidity;
    }

    function removeLiquidity(uint256 _amount)
        public
        payable
        returns (uint256, uint256)
    {
        // console.log('****removeLiquidity');

        require(_amount > 0, "invalid amount");

        uint256 ethReserve = address(this).balance;

        require(ethReserve > 0, "Eth amount is 0");

        uint256 supply = totalSupply();
        uint256 ethAmount = (ethReserve * _amount) / supply;
        uint256 tokenAmount = (getReserve() * _amount) / supply;

        // Burn the liquidity tokens
        _burn(msg.sender, _amount);

        // Transfer the ETH and tokens to the user
        payable(msg.sender).transfer(ethAmount);

        // Transfer the tokens to the user
        IERC20(tokenAddress).approve(msg.sender, tokenAmount);
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        emit LiquidityRemoved(msg.sender, ethAmount, tokenAmount);

        return (ethAmount, tokenAmount);
    }

    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

        // return (inputAmount * outputReserve) / (inputReserve + inputAmount);
        return numerator / denominator;
    }

    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, "ethSold cannot be zero");
        uint256 tokenReserve = getReserve();
        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "tokenSold cannot be zero");
        uint256 tokenReserve = getReserve();
        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function ethToTokenTransfer(uint256 _minTokens, address recipient)
        public
        payable
    {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );

        require(tokensBought >= _minTokens, "insufficient output amount");
        IERC20(tokenAddress).approve(recipient, tokensBought);
        IERC20(tokenAddress).transfer(recipient, tokensBought);

        emit TokenBought(msg.sender, msg.value, tokensBought);
    }

    function ethToToken(uint256 _minTokens) public payable {
        ethToTokenTransfer(_minTokens, msg.sender);
    }

    function tokenToEth(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(
            _tokensSold,
            address(this).balance,
            tokenReserve
        );

        require(ethBought >= _minEth, "insufficient output amount");

        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        payable(msg.sender).transfer(ethBought);

        emit EthBought(msg.sender, ethBought, _tokensSold);
    }

    function tokenToTokenSwap(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        address _tokenAddress
    ) public payable {
        address exchangeAddress = IRegistry(registryAddress).getExchange(
            _tokenAddress
        );

        require(
            exchangeAddress != address(this) && exchangeAddress != address(0),
            "invalid exchange address"
        );

        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );

        Assignment4Exchange(exchangeAddress).ethToTokenTransfer{
            value: ethBought
        }(_minTokensBought, msg.sender);
    }

    // Donate Ether to the contract
    function donateEther() public payable {
        require(msg.value > 0, "invalid amount");
    }
}
