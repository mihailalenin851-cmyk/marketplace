// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {MyNFT} from "./nft.sol";
import {Test} from "forge-std/Test.sol";


contract MyNftTest is Test {
    MyNFT nft;

    function setUp() public {
        nft = new MyNFT();
    }

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function testCreateNFT() public {
        nft.mint(alice, 1);
        address owner = nft.ownerOf(1);
        require(owner == alice, "Nft owner norm");
    }

    function testTransferNFT() public {
        nft.mint(alice, 2);
        address owner = nft.ownerOf(2);
        require(owner == alice, "Nft owner norm");
        vm.prank(alice);
        nft.transferFrom(alice, bob, 2);
        require(nft.ownerOf(2) == bob, "Transfer failed");
    }
}