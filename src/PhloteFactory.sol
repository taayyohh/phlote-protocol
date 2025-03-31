// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PhloteToken} from "./PhloteToken.sol";
import {PhloteTreasury} from "./PhloteTreasury.sol";
import {PhloteGovernance} from "./PhloteGovernance.sol";

/**
 * @title PhloteFactory
 * @dev Contract to deploy the entire Phlote ecosystem in one transaction with upgradeable contracts
 */
contract PhloteFactory is Ownable {
    address public immutable tokenImplementation;
    address public immutable treasuryImplementation;
    address public immutable governanceImplementation;

    event EcosystemDeployed(
        address indexed deployer,
        address indexed token,
        address indexed treasury,
        address governance
    );

    constructor() Ownable() {
        // Deploy implementations
        tokenImplementation = address(new PhloteToken());
        treasuryImplementation = address(new PhloteTreasury());
        governanceImplementation = address(new PhloteGovernance());
    }

    /**
     * @dev Deploys the entire Phlote ecosystem with upgradeable proxies
     * @return token Address of the deployed token proxy
     * @return treasury Address of the deployed treasury proxy
     * @return governance Address of the deployed governance proxy
     */
    function deployEcosystem() external returns (address token, address payable treasury, address governance) {
        // Deploy proxies
        token = Clones.clone(tokenImplementation);
        treasury = payable(Clones.clone(treasuryImplementation));
        governance = Clones.clone(governanceImplementation);

        // Initialize contracts
        PhloteToken(token).initialize(address(this));
        PhloteTreasury(treasury).initialize(address(this), token);
        PhloteGovernance(governance).initialize(address(this), token, treasury);

        // Set up permissions
        PhloteToken(token).addMinter(governance);
        PhloteTreasury(treasury).setGovernanceContract(governance);

        // Transfer ownership to deployer
        PhloteToken(token).transferOwnership(msg.sender);
        PhloteTreasury(treasury).transferOwnership(msg.sender);
        PhloteGovernance(governance).transferOwnership(msg.sender);

        emit EcosystemDeployed(msg.sender, token, treasury, governance);
    }
}
