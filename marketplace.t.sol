// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {Marketplace} from "./marketplace.sol";
import {MyNFT} from "./nft.sol";
import {MyToken} from "./token.sol";
import {Test} from "forge-std/Test.sol";


contract MyMarketplaceTest is Test {
    Marketplace marketplace;
    MyToken token;
    MyNFT nft;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address artem = makeAddr("artem");

    function setUp() public {
        nft = new MyNFT();
        token = new MyToken(alice);

        address[] memory paymentsToken = new address[](1);
        paymentsToken[0] = address(token);

        marketplace = new Marketplace(
            alice,
            artem,
            250,
            paymentsToken
        );
    }

    function testListItem() public {
        nft.mint(bob, 1);
        address owner = nft.ownerOf(1);
        require(owner == bob, "Nft owner norm");
        
        vm.prank(bob);
        nft.approve(address(marketplace), 1);

        uint price = 5_000 * 10 ** token.decimals();

        vm.prank(bob);
        marketplace.listItem(address(nft), 1, address(token), price);
        Marketplace.Listing memory listing = marketplace.getListing(address(nft), 1);
        require(listing.active, "nft not found");
    }

    function testCreateNFT() public {
        nft.mint(alice, 1);
        address owner = nft.ownerOf(1);
        require(owner == alice, "Nft owner norm");
    }

    function testTotalSupply() public view {
        uint256 totalSupply = 100_000*10**token.decimals();
        require(token.totalSupply() == totalSupply, "totalSupply should be 100_000*10**12");
    }
    function testUpdateListing() public{
        nft.mint(bob,1);
        address owner = nft.ownerOf(1);
        require(owner == bob,"NFT owner norm");
        vm.prank(bob);
        nft.approve(address(marketplace), 1);
        uint price = 5_000 * 10 ** token.decimals();
        vm.prank(bob);
        marketplace.listItem(address(nft), 1, address(token), price);
        uint newPrice = 7_500 * 10 ** token.decimals();
        vm.prank(bob);
        marketplace.updateListing(address(nft), 1, address(token), newPrice);
        marketplace.Listing memory listing = marketplace.getListing(address(nft), 1);
        require(listing.active == true, "Listing must be active");
        require(listing.price == newPrice, "Price was not updated");
        require(listing.seller == bob, "Seller mismatch");
        require(listing.paymentToken == address(token), "Token mismatch");


    }


    

}