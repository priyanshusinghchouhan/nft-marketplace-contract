// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/src/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "./mocks/MockNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketplace;
    MockNFT public nft;

    address public seller = address(1);
    address public buyer = address(2);
    address public otherUser = address(3);

    uint256 public tokenId;
    uint256 public constant PRICE = 1 ether;

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();

        vm.prank(seller);
        tokenId = nft.mint(seller);

        vm.deal(buyer, 10 ether);
        vm.deal(otherUser, 10 ether);
    }

    /* ============ LIST NFT TESTS ============ */
    function testListNft() public {
        vm.startPrank(seller);

        nft.setApprovalForAll(address(marketplace), true);

        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        (
            address listedSeller,
            address listedNftContract,
            uint256 listedTokenId,
            uint256 listedPrice,
            bool active
        ) = marketplace.getListing(listingId);

        assertEq(listedSeller, seller);
        assertEq(listedNftContract, address(nft));
        assertEq(listedTokenId, tokenId);
        assertEq(listedPrice, PRICE);
        assertTrue(active);

        console.log("seller: ", seller);
        console.log("nftContract: ", address(nft));
        console.log("tokenId: ", tokenId);
        console.log("price: ", PRICE);
        console.log("active: ", active);

        vm.stopPrank();
    }

    function testListNftEmitsEvent() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);

        vm.expectEmit(true, true, true, true);
        emit NFTMarketplace.NFTListed(0, seller, address(nft), tokenId, PRICE);

        marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();
    }

    function testListNftRevertsIfPriceZero() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);

        vm.expectRevert("Price must be greater than 0");
        marketplace.listNft(address(nft), tokenId, 0);

        vm.stopPrank();
    }

    function testListNftRevertsIfInvalidContract() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);

        vm.expectRevert("Invalid NFT contract");
        marketplace.listNft(address(0), tokenId, PRICE);

        vm.stopPrank();
    }

    function testListNftRevertsIfNotOwner() public {
        vm.startPrank(otherUser);
        nft.setApprovalForAll(address(marketplace), true);

        vm.expectRevert("Not the NFT Owner");
        marketplace.listNft(address(nft), tokenId, PRICE);

        vm.stopPrank();
    }

    function testListNftRevertsIfNotApproved() public {
        vm.startPrank(seller);

        vm.expectRevert("Marketplace not approved");
        marketplace.listNft(address(nft), tokenId, PRICE);

        vm.stopPrank();
    }

    function testListNftRevertsIfAlreadyListed() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        
        marketplace.listNft(address(nft), tokenId, PRICE);

        vm.expectRevert("NFT already listed");
        marketplace.listNft(address(nft), tokenId, PRICE);

        vm.stopPrank();
    }

    function testListNftIncreasesListingCounter() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
    
        assertEq(marketplace.getTotalListings(), 0);

        marketplace.listNft(address(nft), tokenId, PRICE);
        assertEq(marketplace.getTotalListings(), 1);

        vm.stopPrank();
    }
}