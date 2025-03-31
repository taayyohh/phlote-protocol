// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {PhloteFactory} from "../src/PhloteFactory.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy factory
        PhloteFactory factory = new PhloteFactory();
        console2.log("Factory deployed at:", address(factory));

        // Deploy ecosystem
        (address token, address treasury, address governance) = factory.deployEcosystem();

        console2.log("Token deployed at:", token);
        console2.log("Treasury deployed at:", treasury);
        console2.log("Governance deployed at:", governance);

        vm.stopBroadcast();
    }
} 