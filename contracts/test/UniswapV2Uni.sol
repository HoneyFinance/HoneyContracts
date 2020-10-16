// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniswapV2Uni is ERC20 {
    using Address for address;
    using SafeMath for uint;

    constructor () public ERC20("Uniswap V2", "LP") {
        _mint(msg.sender, 100000 * 10**18);
    }
}