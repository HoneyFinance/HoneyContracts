// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../interfaces/IHoneyPropDict.sol";

contract MockHoneyPropDict is IHoneyPropDict {

  function getMiningMultiplier(uint256 tokenId) external view override returns (uint256) {
    if (tokenId == 1) {
      return 150;
    } else if (tokenId == 2) {
      return 400;
    } else {
      return 100;
    }
  }
}
