// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {MyToken} from "./token.sol";
import {Test} from "forge-std/Test.sol";


contract MyTokenTest is Test {
    MyToken token;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address artem = makeAddr("artem");


    function setUp() public {
        token = new MyToken(alice);
    }

    function testTotalSupply() public view {
        uint256 totalSupply = 100_000*10**token.decimals();
        require(token.totalSupply() == totalSupply, "totalSupply should be 100_000*10**12");
    }

    function testDecimals() public view {
        require(token.decimals() == 18, "18");
    }
    
    function testOwnerSupply() public view {
        uint balanceOwner = token.balanceOf(alice);
        require(balanceOwner == token.totalSupply(), "Owner balance not supply");
    }

    function testTransferToken() public {
        uint amount = 10_000*10**token.decimals();
        vm.prank(alice);
        token.transfer(bob, amount);
        uint balanceBob = token.balanceOf(bob);
        require(balanceBob == amount, "Bob low balance");
    }

    function testApproved() public {
        uint amount = 10_000*10**token.decimals();
        vm.prank(alice);
        token.approve(bob, amount);
        require(token.allowance(alice, bob) == amount, "bob poor");

        vm.prank(bob);
        token.transferFrom(alice, artem, amount);
        require(token.balanceOf(artem) == amount, "artem poor");

        require(token.allowance(alice, bob) == 0, "bob rich");
    }
    


}