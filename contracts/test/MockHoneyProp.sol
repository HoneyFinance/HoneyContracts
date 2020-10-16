// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockHoneyProp is ERC721, Ownable {
    mapping(address => bool) public minters;

    constructor () public ERC721("Honey Prop", "HPROP") {
        _setBaseURI("https://app.myhoney.finance/api/prop/");
    }

    function addMinter(address minter) public onlyOwner {
        minters[minter] = true;
    }

    function removeMinter(address minter) public onlyOwner {
        minters[minter] = false;
    }

    function mint(address to, uint256 tokenId) external returns (bool) {
        require(minters[msg.sender], "!minter");
        _mint(to, tokenId);
        _setTokenURI(tokenId, Strings.toString(tokenId));
        return true;
    }

    function safeMint(address to, uint256 tokenId) public returns (bool) {
        require(minters[msg.sender], "!minter");
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, Strings.toString(tokenId));
        return true;
    }

    // Destroys `tokenId`.
    function burn(uint256 tokenId) external {
        //solhint-disable-next-line max-line-length
        require(minters[msg.sender], "!minter");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "caller is not owner nor approved");
        _burn(tokenId);
    }
}
