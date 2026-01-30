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
        vm.deal(seller, 10 ether);
        vm.deal(otherUser, 10 ether);
    }

    /* ========================== LIST NFT TESTS ========================== */

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


    /* ========================== BUY NFT TESTS ========================== */

    function testBuyNftSuccess() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);

        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        marketplace.buyNft{value: PRICE}(listingId);

        assertEq(nft.ownerOf(tokenId), buyer);

        assertEq(seller.balance, sellerBalanceBefore + PRICE);
        assertEq(buyer.balance, buyerBalanceBefore - PRICE);

        ( , , , , bool active) = marketplace.getListing(listingId);
        assertFalse(active);
    }

    function testBuyNftEmitsEvent() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit NFTMarketplace.NFTSold(listingId, buyer, seller, PRICE);

        vm.prank(buyer);
        marketplace.buyNft{value: PRICE}(listingId);
    }

    function testBuyNftRevertsIfListingNotActive() public {
        vm.prank(buyer);
        vm.expectRevert("Listing not active");
        marketplace.buyNft{value: PRICE}(999);
    }

    function testBuyNftRevertsIfIncorrectPrice() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("Incorrect Price");
        marketplace.buyNft{value: 0.5 ether}(listingId);
    }

    function testBuyNftRevertsIfBuyOwnNft() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();

        vm.prank(seller);
        vm.expectRevert("Cannot buy your own NFT");
        marketplace.buyNft{value: PRICE}(listingId);
    }

    function testBuyNftAllowRelistingAfterPurchase() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);

        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();

        vm.prank(buyer);
        marketplace.buyNft{value: PRICE}(listingId);

        vm.startPrank(buyer);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 newlistingId = marketplace.listNft(address(nft), tokenId, PRICE * 2);


        (address newSeller, , , uint256 newPrice , bool active) = marketplace.getListing(newlistingId);
        assertEq(newSeller, buyer);
        assertEq(newPrice, PRICE * 2);
        assertTrue(active);

        vm.stopPrank();
    }

    /* ========================== CANCEL LISTING TESTS ========================== */

    function testCancelListingSuccess() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        marketplace.cancelListing(listingId);

        ( , , , , bool active) = marketplace.getListing(listingId);
        assertFalse(active);

        assertEq(nft.ownerOf(tokenId), seller);

        vm.stopPrank();
    }

    function testCancelListingEmitEvents() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        vm.expectEmit(true, true, true, true);
        emit NFTMarketplace.ListingCancelled(listingId, seller);

        marketplace.cancelListing(listingId);
        vm.stopPrank();
    }

    function testCancelListingRevertsIfNotSeller() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();


        vm.prank(buyer);
        vm.expectRevert("Not the seller");
        marketplace.cancelListing(listingId);   
    }

    function testCancelListingRevertsIfAlreadyInactive() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        marketplace.cancelListing(listingId);  

        vm.expectRevert("Listing not active");
        marketplace.cancelListing(listingId); 

        vm.stopPrank(); 
    }

    function testCancelListingAllowsRelisting() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        marketplace.cancelListing(listingId);  

        uint256 newListingId = marketplace.listNft(address(nft), tokenId, PRICE * 2);

        (address newSeller, , , uint256 newPrice , bool active) = marketplace.getListing(newListingId);

        assertTrue(active);
        assertEq(newPrice, PRICE * 2);
        assertEq(newSeller, seller);

        vm.stopPrank(); 
    }

    /* ========================== UPDATE PRICE TESTS ========================== */

    function testUpdatePriceSuccess() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        marketplace.updateListingPrice(listingId, PRICE * 2);

        ( , , ,uint256 newPrice , bool active) = marketplace.getListing(listingId);

        assertTrue(active);
        assertEq(newPrice, PRICE * 2);

        vm.stopPrank();
    }

    function testUpdatePriceEmitsEvent() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        uint256 newPrice = 2 ether;

        vm.expectEmit(true, true, true, true);
        emit NFTMarketplace.ListingPriceUpdated(listingId, newPrice);

        marketplace.updateListingPrice(listingId, newPrice);

        vm.stopPrank();
    }

    function testUpdatePriceRevertsIfNotSeller() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);
        vm.stopPrank();

        uint256 newPrice = 2 ether;

        vm.prank(otherUser);
        vm.expectRevert("Not the seller");
        marketplace.updateListingPrice(listingId, newPrice);
    }

    function testUpdatePriceRevertsIfListingNotActive() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.listNft(address(nft), tokenId, PRICE);

        marketplace.cancelListing(listingId);

        vm.expectRevert("Listing not active");
        marketplace.updateListingPrice(listingId, PRICE * 2);

        vm.stopPrank();
    }

}