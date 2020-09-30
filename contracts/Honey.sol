// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";

contract Honey is ERC20Capped {
    using Address for address;
    using SafeMath for uint;

    address public governance;

    constructor (uint256 cap) public
    ERC20("Honey Finance", "HONEY")
    ERC20Capped(cap)
    {
        governance = msg.sender;
    }

    function mint(address account, uint amount) public {
        require(msg.sender == governance, "!governance");
        _mint(account, amount);
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }
}