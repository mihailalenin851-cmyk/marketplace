// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract marketplace {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;       
        address paymentToken; 
        uint256 price;        
        bool active;
    }

    address public owner;
    uint96 public feeBps;            
    address public feeRecipient;     
    bool public paused;
    bool private _locked;

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => bool) public allowedPaymentTokens;

    event ItemListed(address indexed seller, address indexed nft, uint256 indexed tokenId, address paymentToken, uint256 price);
    event ItemUpdated(address indexed seller, address indexed nft, uint256 indexed tokenId, address paymentToken, uint256 price);
    event ItemCanceled(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event ItemSold(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, address paymentToken, uint256 price, uint256 fee);
    event PaymentTokenStatusChanged(address indexed token, bool allowed);
    event FeeStatusChanged(uint96 feeBps);
    event FeeRecipientStatusChanged(address indexed feeRecipient);
    event PausedStatusChanged(bool isPaused);

    error NotOwner();
    error NotApprovedForMarketplace();
    error AlreadyListed();
    error NotListed();
    error PriceMustBeAboveZero();
    error PaymentTokenNotAllowed();
    error PriceMismatch();
    error TokenMismatch();
    error SellerNoLongerOwner();
    error FeeTooHigh();
    error ZeroAddress();
    error IsPaused();
    error ReentrancyGuard();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlySeller(address nft, uint256 tokenId) {
        if (!listings[nft][tokenId].active) revert NotListed();
        if (listings[nft][tokenId].seller != msg.sender) revert NotOwner();
        _;
    }

    modifier onlyBuyer(address nft, uint256 tokenId) {
        if (listings[nft][tokenId].seller == msg.sender) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert IsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyGuard();
        _locked = true;
        _;
        _locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function listItem(address nft, uint256 tokenId, address paymentToken, uint256 price) external whenNotPaused {
        if (price == 0) revert PriceMustBeAboveZero();
        if (!allowedPaymentTokens[paymentToken]) revert PaymentTokenNotAllowed();
        if (listings[nft][tokenId].active) revert AlreadyListed();
        
        IERC721 nftContract = IERC721(nft);
        if (nftContract.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (nftContract.getApproved(tokenId) != address(this) && !nftContract.isApprovedForAll(msg.sender, address(this))) {
            revert NotApprovedForMarketplace();
        }

        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            paymentToken: paymentToken,
            price: price,
            active: true
        });

        emit ItemListed(msg.sender, nft, tokenId, paymentToken, price);
    }

    function updateListing(address nft, uint256 tokenId, address paymentToken, uint256 price) external whenNotPaused onlySeller(nft, tokenId) {
        if (price == 0) revert PriceMustBeAboveZero();
        if (!allowedPaymentTokens[paymentToken]) revert PaymentTokenNotAllowed();

        IERC721 nftContract = IERC721(nft);
        if (nftContract.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (nftContract.getApproved(tokenId) != address(this) && !nftContract.isApprovedForAll(msg.sender, address(this))) {
            revert NotApprovedForMarketplace();
        }

        Listing storage listing = listings[nft][tokenId];
        listing.paymentToken = paymentToken;
        listing.price = price;

        emit ItemUpdated(msg.sender, nft, tokenId, paymentToken, price);
    }

    function cancelListing(address nft, uint256 tokenId) external onlySeller(nft, tokenId) {
        delete listings[nft][tokenId];
        emit ItemCanceled(msg.sender, nft, tokenId);
    }

    function buyItem(address nft, uint256 tokenId, address expectedToken, uint256 expectedPrice) external nonReentrant whenNotPaused onlyBuyer(nft, tokenId) {
        Listing memory listing = listings[nft][tokenId];
        if (!listing.active) revert NotListed();
        if (listing.price != expectedPrice) revert PriceMismatch();
        if (listing.paymentToken != expectedToken) revert TokenMismatch();

        IERC721 nftContract = IERC721(nft);
        address seller = listing.seller;
        
        if (nftContract.ownerOf(tokenId) != seller) revert SellerNoLongerOwner();
        if (nftContract.getApproved(tokenId) != address(this) && !nftContract.isApprovedForAll(seller, address(this))) {
            revert NotApprovedForMarketplace();
        }

        delete listings[nft][tokenId];

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
        if (bps > 1000) revert FeeTooHigh();
        feeBps = bps;
        emit FeeStatusChanged(bps);
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        feeRecipient = recipient;
        emit FeeRecipientStatusChanged(recipient);
    }

    function pause() external onlyOwner {
        paused = true;
        emit PausedStatusChanged(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit PausedStatusChanged(false);
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
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
