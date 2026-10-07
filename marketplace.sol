// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Marketplace is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;       
        address paymentToken; 
        uint256 price;        
        bool active;
    }

    uint96 public feeBps;            
    address public feeRecipient;     

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => bool) public allowedPaymentTokens;

    event ItemListed(address indexed seller, address indexed nft, uint256 indexed tokenId, address paymentToken, uint256 price);
    event ItemUpdated(address indexed seller, address indexed nft, uint256 indexed tokenId, address paymentToken, uint256 price);
    event ItemCanceled(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event ItemSold(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, address paymentToken, uint256 price, uint256 fee);
    event PaymentTokenStatusChanged(address indexed token, bool allowed);
    event FeeStatusChanged(uint96 feeBps);
    event FeeRecipientStatusChanged(address indexed feeRecipient);

    modifier onlySeller(address nft, uint256 tokenId) {
        require(listings[nft][tokenId].active, "Not listed");
        require(listings[nft][tokenId].seller == msg.sender, "Not seller");
        _;
    }

    modifier onlyBuyer(address nft, uint256 tokenId) {
        require(listings[nft][tokenId].active, "Not listed");
        require(listings[nft][tokenId].seller != msg.sender, "Is seller");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function listItem(address nft, uint256 tokenId, address paymentToken, uint256 price) external whenNotPaused nonReentrant {
        require(price > 0, "Price must be above zero");
        require(allowedPaymentTokens[paymentToken], "Payment token not allowed");
        require(!listings[nft][tokenId].active, "Already listed");
        
        IERC721 nftContract = IERC721(nft);
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not owner of NFT");
        require(
            nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(msg.sender, address(this)),
            "Not approved for marketplace"
        );

        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            paymentToken: paymentToken,
            price: price,
            active: true
        });

        emit ItemListed(msg.sender, nft, tokenId, paymentToken, price);
    }

    function updateListing(address nft, uint256 tokenId, address paymentToken, uint256 price) external whenNotPaused nonReentrant onlySeller(nft, tokenId) {
        require(price > 0, "Price must be above zero");
        require(allowedPaymentTokens[paymentToken], "Payment token not allowed");

        IERC721 nftContract = IERC721(nft);
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not owner of NFT");
        require(
            nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(msg.sender, address(this)),
            "Not approved for marketplace"
        );

        Listing storage listing = listings[nft][tokenId];
        listing.paymentToken = paymentToken;
        listing.price = price;
        delete listings[nft][tokenId];
        emit ItemUpdated(msg.sender, nft, tokenId, paymentToken, price);
    }

    function cancelListing(address nft, uint256 tokenId) external nonReentrant onlySeller(nft, tokenId) {
        delete listings[nft][tokenId];
        emit ItemCanceled(msg.sender, nft, tokenId);
    }

    function buyItem(address nft, uint256 tokenId, address expectedToken, uint256 expectedPrice) external whenNotPaused nonReentrant onlyBuyer(nft, tokenId) {
        Listing memory listing = listings[nft][tokenId];
        require(listing.price == expectedPrice, "Price mismatch");
        require(listing.paymentToken == expectedToken, "Token mismatch");

        IERC721 nftContract = IERC721(nft);
        address seller = listing.seller;
        
        require(nftContract.ownerOf(tokenId) == seller, "Seller no longer owner");
        require(
            nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(seller, address(this)),
            "Not approved for marketplace"
        );

        

        uint256 fee = (listing.price * feeBps) / 10000;
        uint256 sellerAmount = listing.price - fee;

        IERC20 token = IERC20(listing.paymentToken);
        
        token.safeTransferFrom(msg.sender, seller, sellerAmount);
        if (fee > 0) {
            token.safeTransferFrom(msg.sender, feeRecipient, fee);
        }

        nftContract.safeTransferFrom(seller, msg.sender, tokenId);

        emit ItemSold(msg.sender, seller, nft, tokenId, listing.paymentToken, listing.price, fee);
    }

    function setPaymentToken(address token, bool allowed) external onlyOwner {
        allowedPaymentTokens[token] = allowed;
        emit PaymentTokenStatusChanged(token, allowed);
    }

    function setFee(uint96 bps) external onlyOwner {
        require(bps <= 1000, "Fee too high");
        feeBps = bps;
        emit FeeStatusChanged(bps);
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "Zero address");
        feeRecipient = recipient;
        emit FeeRecipientStatusChanged(recipient);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero address");
        IERC20(token).safeTransfer(to, amount);
    }

    function getListing(address nft, uint256 tokenId) external view returns (Listing memory) {
        return listings[nft][tokenId];
    }

    function isListingValid(address nft, uint256 tokenId) external view returns (bool) {
        Listing memory listing = listings[nft][tokenId];
        if (!listing.active) return false;
        
        IERC721 nftContract = IERC721(nft);
        try nftContract.ownerOf(tokenId) returns (address currentOwner) {
            if (currentOwner != listing.seller) return false;
            return (nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(listing.seller, address(this)));
        } catch {
            return false;
        }
    }
}
