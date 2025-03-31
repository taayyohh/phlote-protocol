// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title PhloteTreasury
 * @dev Contract that holds the reserve funds from subscription revenues
 * The treasury captures subscription revenue and allows Points holders to claim their share
 * Implements UUPS upgradeable pattern
 */
contract PhloteTreasury is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public phloteToken;
    address public governanceContract;

    uint256 public totalReserve;
    uint256 public totalDistributed;
    uint256 public distributionRatio = 5000; // 50% in basis points (5000/10000)

    mapping(address => uint256) public lastClaimTimestamp;

    event RevenueReceived(address indexed from, uint256 amount);
    event ReserveClaimed(address indexed to, uint256 amount);
    event DistributionRatioUpdated(uint256 newRatio);
    event GovernanceContractUpdated(address indexed newContract);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract replacing the constructor for upgradeable contracts
     */
    function initialize(address initialOwner, address _phloteToken) public initializer {
        __Ownable_init();
        _transferOwnership(initialOwner);
        __UUPSUpgradeable_init();
        phloteToken = IERC20Upgradeable(_phloteToken);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Sets the governance contract address
     * @param _governanceContract Address of the governance contract
     */
    function setGovernanceContract(address _governanceContract) external onlyOwner {
        governanceContract = _governanceContract;
        emit GovernanceContractUpdated(_governanceContract);
    }

    /**
     * @dev Updates the distribution ratio
     * @param _ratio New ratio in basis points (10000 = 100%)
     */
    function setDistributionRatio(uint256 _ratio) external onlyOwner {
        require(_ratio <= 10000, "Ratio must be <= 10000");
        distributionRatio = _ratio;
        emit DistributionRatioUpdated(_ratio);
    }

    /**
     * @dev Receives subscription revenue into the treasury
     */
    function receiveRevenue() external payable {
        totalReserve += msg.value;
        emit RevenueReceived(msg.sender, msg.value);
    }

    /**
     * @dev Allows Points holders to claim their share of the reserve
     * The amount is proportional to their token holdings
     */
    function claimReserveShare() external {
        require(phloteToken.balanceOf(msg.sender) > 0, "No Points balance");

        // Simple mechanism: share based on percentage of total supply
        uint256 totalSupply = phloteToken.totalSupply();
        uint256 userBalance = phloteToken.balanceOf(msg.sender);

        // Calculate user's share of the reserve
        uint256 availableToDistribute = (totalReserve * distributionRatio) / 10000;
        uint256 userShare = (availableToDistribute * userBalance) / totalSupply;

        // Prevent claiming too frequently
        require(block.timestamp > lastClaimTimestamp[msg.sender] + 30 days, "Can claim once per month");
        lastClaimTimestamp[msg.sender] = block.timestamp;

        // Update state and transfer ETH
        totalDistributed += userShare;
        totalReserve -= userShare;

        (bool success, ) = payable(msg.sender).call{value: userShare}("");
        require(success, "Transfer failed");

        emit ReserveClaimed(msg.sender, userShare);
    }

    /**
     * @dev Only the governance contract can withdraw from treasury for artist rewards
     * @param amount Amount to withdraw
     * @param recipient Recipient address (should be an artist)
     */
    function withdrawForArtistReward(uint256 amount, address recipient) external {
        require(msg.sender == governanceContract, "Only governance");
        require(amount <= totalReserve, "Insufficient reserve");

        totalReserve -= amount;
        totalDistributed += amount;

        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transfer failed");

        emit ReserveClaimed(recipient, amount);
    }

    // Function to handle receiving ETH
    receive() external payable {
        totalReserve += msg.value;
        emit RevenueReceived(msg.sender, msg.value);
    }
}
