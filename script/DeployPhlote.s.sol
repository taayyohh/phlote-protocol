// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PhloteFactory.sol";

contract DeployPhlote is Script {
    function run() external {
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory
        PhloteFactory factory = new PhloteFactory();

        // Deploy the ecosystem
        (address token, address treasury, address governance) = factory.deployEcosystem();

        // Log the deployed addresses
        console.log("PhloteToken proxy deployed at:", token);
        console.log("PhloteTreasury proxy deployed at:", treasury);
        console.log("PhloteGovernance proxy deployed at:", governance);

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
