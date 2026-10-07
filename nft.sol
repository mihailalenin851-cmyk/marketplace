// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.7.0
pragma solidity ^0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract MyNFT is ERC721, Ownable {
    constructor() ERC721("MyToken", "MTK")Ownable(msg.sender) {}
        function mint(address _to, uint _tokenId) public onlyOwner {
        _mint(_to, _tokenId);
    }
}