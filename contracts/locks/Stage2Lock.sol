// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/TokenTimelock.sol";

contract Stage2Lock is TokenTimelock {
    constructor (address _honey, address _beneficiary, uint256 _releaseTime) public
    TokenTimelock(IERC20(_honey), _beneficiary, _releaseTime) {
    }
}
