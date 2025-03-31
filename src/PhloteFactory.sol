// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./PhloteToken.sol";
import "./PhloteTreasury.sol";
import "./PhloteGovernance.sol";

/**
 * @title PhloteFactory
 * @dev Contract to deploy the entire Phlote ecosystem in one transaction with upgradeable contracts
 */
contract PhloteFactory {
    event EcosystemDeployed(
        address indexed deployer,
        address token,
        address treasury,
        address governance,
        address tokenImplementation,
        address treasuryImplementation,
        address governanceImplementation
    );

    /**
     * @dev Deploys the entire Phlote ecosystem with upgradeable proxies
     * @return token Address of the deployed token proxy
     * @return treasury Address of the deployed treasury proxy
     * @return governance Address of the deployed governance proxy
     */
    function deployEcosystem() public returns (
        address token,
        address payable treasury,
        address governance
    ) {
        address deployer = msg.sender;

        // Deploy Token implementation
        PhloteToken tokenImplementation = new PhloteToken();

        // Deploy Token proxy
        bytes memory tokenData = abi.encodeWithSelector(
            PhloteToken.initialize.selector,
            address(this)
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(
            address(tokenImplementation),
            tokenData
        );
        token = address(tokenProxy);

        // Deploy Treasury implementation
        PhloteTreasury treasuryImplementation = new PhloteTreasury();

        // Deploy Treasury proxy
        bytes memory treasuryData = abi.encodeWithSelector(
            PhloteTreasury.initialize.selector,
            address(this),
            token
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(
            address(treasuryImplementation),
            treasuryData
        );
        treasury = payable(address(treasuryProxy));

        // Deploy Governance implementation
        PhloteGovernance governanceImplementation = new PhloteGovernance();

        // Deploy Governance proxy
        bytes memory governanceData = abi.encodeWithSelector(
            PhloteGovernance.initialize.selector,
            address(this),
            token,
            treasury
        );
        ERC1967Proxy governanceProxy = new ERC1967Proxy(
            address(governanceImplementation),
            governanceData
        );
        governance = address(governanceProxy);

        // Set up permissions
        PhloteToken(token).addMinter(governance);
        PhloteTreasury(treasury).setGovernanceContract(governance);

        // Transfer ownership to deployer
        PhloteToken(token).transferOwnership(deployer);
        PhloteTreasury(treasury).transferOwnership(deployer);
        PhloteGovernance(governance).transferOwnership(deployer);

        emit EcosystemDeployed(
            deployer,
            token,
            treasury,
            governance,
            address(tokenImplementation),
            address(treasuryImplementation),
            address(governanceImplementation)
        );

        return (token, treasury, governance);
    }
}
