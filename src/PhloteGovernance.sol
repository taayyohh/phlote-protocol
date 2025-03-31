// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./PhloteToken.sol";
import "./PhloteTreasury.sol";

/**
 * @title PhloteGovernance
 * @dev Contract that manages the distribution of Points to artists
 * Also manages the relationship between subscriber growth and token value
 * Implements UUPS upgradeable pattern
 */
contract PhloteGovernance is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice The Phlote token contract
    PhloteToken public phloteToken;
    PhloteTreasury public phloteTreasury;

    uint256 public subscriberCount;
    uint256 public artistCount;

    struct Artist {
        bool registered;
        uint256 totalEarned;
        uint256 lastRewardTimestamp;
    }

    mapping(address => bool) public operators;
    mapping(address => Artist) public artists;
    mapping(address => bool) public subscribers;

    event ArtistRegistered(address indexed artist);
    event ArtistRewarded(address indexed artist, uint256 pointsAmount, uint256 ethAmount);
    event SubscriberAdded(address indexed subscriber);
    event SubscriberRemoved(address indexed subscriber);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract replacing the constructor for upgradeable contracts
     */
    function initialize(address initialOwner, address _phloteToken, address payable _phloteTreasury) public initializer {
        __Ownable_init();
        _transferOwnership(initialOwner);
        __UUPSUpgradeable_init();
        phloteToken = PhloteToken(_phloteToken);
        phloteTreasury = PhloteTreasury(_phloteTreasury);

        // Add self as operator
        operators[initialOwner] = true;
        emit OperatorAdded(initialOwner);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Adds an operator
     * @param operator Address to add as an operator
     */
    function addOperator(address operator) external onlyOwner {
        operators[operator] = true;
        emit OperatorAdded(operator);
    }

    /**
     * @dev Removes an operator
     * @param operator Address to remove as an operator
     */
    function removeOperator(address operator) external onlyOwner {
        operators[operator] = false;
        emit OperatorRemoved(operator);
    }

    /**
     * @dev Registers a new artist
     * @param artist Address of the artist to register
     */
    function registerArtist(address artist) external onlyOperator {
        require(!artists[artist].registered, "Already registered");

        artists[artist] = Artist({
            registered: true,
            totalEarned: 0,
            lastRewardTimestamp: 0
        });

        artistCount++;
        emit ArtistRegistered(artist);
    }

    /**
     * @dev Adds a new subscriber
     * @param subscriber Address of the subscriber to add
     */
    function addSubscriber(address subscriber) external onlyOperator {
        if (!subscribers[subscriber]) {
            subscribers[subscriber] = true;
            subscriberCount++;
            emit SubscriberAdded(subscriber);
        }
    }

    /**
     * @dev Removes a subscriber
     * @param subscriber Address of the subscriber to remove
     */
    function removeSubscriber(address subscriber) external onlyOperator {
        if (subscribers[subscriber]) {
            subscribers[subscriber] = false;
            subscriberCount--;
            emit SubscriberRemoved(subscriber);
        }
    }

    /**
     * @dev Rewards an artist with Points and ETH from the treasury
     * @param artist Address of the artist to reward
     * @param pointsAmount Amount of Points to mint for the artist
     * @param ethAmount Amount of ETH to send from treasury to the artist
     */
    function rewardArtist(address artist, uint256 pointsAmount, uint256 ethAmount) external onlyOperator {
        require(artists[artist].registered, "Artist not registered");
        require(block.timestamp > artists[artist].lastRewardTimestamp + 1 days, "Too frequent");

        // Mint Points tokens to the artist
        phloteToken.mint(artist, pointsAmount);

        // If ETH reward is included, send from treasury
        if (ethAmount > 0) {
            phloteTreasury.withdrawForArtistReward(ethAmount, artist);
        }

        // Update artist's reward record
        artists[artist].totalEarned += pointsAmount;
        artists[artist].lastRewardTimestamp = block.timestamp;

        emit ArtistRewarded(artist, pointsAmount, ethAmount);
    }

    /**
     * @dev Calculates Points reward based on subscriber count and artist contribution
     * @param contributionScore Score representing artist's contribution (1-100)
     * @return Amount of Points to mint
     */
    function calculateReward(uint256 contributionScore) public view returns (uint256) {
        require(contributionScore <= 100, "Score must be <= 100");

        // Base reward
        uint256 baseReward = 100 * 10**18; // 100 Points

        // Multiply by subscriber factor and contribution score
        uint256 subscriberFactor = (subscriberCount / 100) + 1; // Grow with subscriber base

        return (baseReward * subscriberFactor * contributionScore) / 100;
    }
}
