// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NFTMarketplace
 * @dev NFT Marketplace for listing, buying and cancelling NFT sales
 */

contract NFTMarketplace is ReentrancyGuard {
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    uint256 private _listingIdCounter;

    mapping(uint256 => Listing) public listings;
    mapping(address => mapping(uint256 => uint256)) public activeListingByNFT;

    /* EVENTS */
    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );

    event NFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event ListingPriceUpdated(uint256 indexed listingId, uint256 newPrice);

    /**
     * @dev List an NFT for sale
     * @param nftContract Address of the NFT contract
     * @param tokenId Token ID of the NFT
     * @param price Price in wei
     */

    function listNft(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant returns (uint256) {
        require(price > 0, "Price must be greater than 0");
        require(nftContract != address(0), "Invalid NFT contract");

        IERC721 nft = IERC721(nftContract);

        require(nft.ownerOf(tokenId) == msg.sender, "Not the NFT Owner");

        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
                nft.getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );

        uint256 storedId = activeListingByNFT[nftContract][tokenId];

        require(
            storedId == 0 || !listings[storedId - 1].active, "NFT already listed" 
        );

        uint256 listingId = _listingIdCounter++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        activeListingByNFT[nftContract][tokenId] = listingId + 1;

        emit NFTListed(listingId, msg.sender, nftContract, tokenId, price);

        return listingId;
    }

    /**
     * @dev Buy an NFT from a listing
     * @param listingId ID of the listing
     */

    function buyNft(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(msg.value == listing.price, "Incorrect Price");
        require(msg.sender != listing.seller, "Cannot buy your own NFT");

        listing.active = false;
        delete activeListingByNFT[listing.nftContract][listing.tokenId];

        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Payment transfer failed");

        emit NFTSold(listingId, msg.sender, listing.seller, msg.value);
    }

    /**
     * @dev Cancel a listing
     * @param listingId ID of the listing
     */

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not the seller");

        listing.active = false;
        delete activeListingByNFT[listing.nftContract][listing.tokenId];

        emit ListingCancelled(listingId, listing.seller);
    }

    function updateListingPrice(uint256 listingId, uint256 newPrice) external {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not the seller");
        require(newPrice > 0, "Price must be greater than 0");

        listing.price = newPrice;

        emit ListingPriceUpdated(listingId, newPrice);
    }

    /**
     * @dev Get listing details
     * @param listingId ID of the listing
     */

    function getListing(
        uint256 listingId
    )
        external
        view
        returns (
            address seller,
            address nftContract,
            uint256 tokenId,
            uint256 price,
            bool active
        )
    {
        Listing memory listing = listings[listingId];
        return (
            listing.seller,
            listing.nftContract,
            listing.tokenId,
            listing.price,
            listing.active
        );
    }

    /**
     * @dev Get total number of listings created
     */

    function getTotalListings() external view returns (uint256) {
        return _listingIdCounter;
    }
}
