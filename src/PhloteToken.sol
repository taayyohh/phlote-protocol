// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

/**
 * @title PhloteToken
 * @dev ERC20 token representing "Points" in the Phlote ecosystem
 * Can only be minted by authorized addresses (PhloteGovernance)
 * Implements UUPS upgradeable pattern
 */
contract PhloteToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ERC20PermitUpgradeable {
    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract replacing the constructor for upgradeable contracts
     */
    function initialize(address initialOwner) public initializer {
        __ERC20_init("Phlote", "PHLOTE");
        __ERC20Permit_init("Phlote");
        __ERC20Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Adds an address to the minters list
     * @param minter Address to add as a minter
     */
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    /**
     * @dev Removes an address from the minters list
     * @param minter Address to remove as a minter
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    /**
     * @dev Mints tokens to the specified address
     * @param to Recipient of the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "Only minters can mint");
        _mint(to, amount);
    }
}
