// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IHoneyPropDict {
  function getMiningMultiplier(uint256 tokenId) external view returns (uint256); // in percentage, 100 denotes 100%
}
