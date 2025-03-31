// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/PhloteToken.sol";
import "../src/PhloteTreasury.sol";
import "../src/PhloteGovernance.sol";
import "../src/PhloteFactory.sol";

contract PhloteEcosystemTest is Test {
    PhloteToken public tokenImplementation;
    PhloteTreasury public treasuryImplementation;
    PhloteGovernance public governanceImplementation;

    PhloteToken public token;
    PhloteTreasury public treasury;
    PhloteGovernance public governance;
    PhloteFactory public factory;

    address public owner = address(1);
    address public artist = address(2);
    address public subscriber1 = address(3);
    address public subscriber2 = address(4);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementations
        tokenImplementation = new PhloteToken();
        treasuryImplementation = new PhloteTreasury();
        governanceImplementation = new PhloteGovernance();

        // Deploy proxies
        bytes memory tokenData = abi.encodeWithSelector(
            PhloteToken.initialize.selector,
            owner
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(
            address(tokenImplementation),
            tokenData
        );
        token = PhloteToken(address(tokenProxy));

        bytes memory treasuryData = abi.encodeWithSelector(
            PhloteTreasury.initialize.selector,
            owner,
            address(token)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(
            address(treasuryImplementation),
            treasuryData
        );
        treasury = PhloteTreasury(payable(address(treasuryProxy)));

        bytes memory governanceData = abi.encodeWithSelector(
            PhloteGovernance.initialize.selector,
            owner,
            address(token),
            address(treasury)
        );
        ERC1967Proxy governanceProxy = new ERC1967Proxy(
            address(governanceImplementation),
            governanceData
        );
        governance = PhloteGovernance(address(governanceProxy));

        // Set up permissions
        token.addMinter(address(governance));
        treasury.setGovernanceContract(address(governance));

        // Deploy factory separately
        factory = new PhloteFactory();

        vm.stopPrank();
    }

    function testFactoryDeployment() public {
        // Deploy via factory as the test contract
        vm.startPrank(address(this));
        (address tokenAddr, address payable treasuryAddr, address governanceAddr) = factory.deployEcosystem();

        // Verify contracts were deployed
        assertTrue(tokenAddr != address(0), "Token not deployed");
        assertTrue(treasuryAddr != address(0), "Treasury not deployed");
        assertTrue(governanceAddr != address(0), "Governance not deployed");

        // Verify ownership - the owner should be this test contract since it's the deployer
        PhloteToken deployedToken = PhloteToken(tokenAddr);
        PhloteTreasury deployedTreasury = PhloteTreasury(treasuryAddr);
        PhloteGovernance deployedGovernance = PhloteGovernance(governanceAddr);

        assertEq(deployedToken.owner(), address(this), "Token owner not set correctly");
        assertEq(deployedTreasury.owner(), address(this), "Treasury owner not set correctly");
        assertEq(deployedGovernance.owner(), address(this), "Governance owner not set correctly");

        // Verify permissions
        assertTrue(deployedToken.minters(governanceAddr), "Governance not set as minter");
        assertEq(deployedTreasury.governanceContract(), governanceAddr, "Governance contract not set in treasury");

        vm.stopPrank();
    }

    function testArtistReward() public {
        vm.startPrank(owner);

        // Register artist
        governance.registerArtist(artist);
        (bool registered,,) = governance.artists(artist);
        assertTrue(registered, "Artist not registered");

        // Add subscribers to increase token value
        governance.addSubscriber(subscriber1);
        governance.addSubscriber(subscriber2);
        assertEq(governance.subscriberCount(), 2, "Subscriber count incorrect");

        // Add ETH to treasury
        vm.deal(owner, 10 ether);
        treasury.receiveRevenue{value: 5 ether}();
        assertEq(address(treasury).balance, 5 ether, "Treasury balance incorrect");

        // Warp time forward to bypass cooldown
        vm.warp(block.timestamp + 31 days);

        // Reward artist
        uint256 pointsAmount = 100 * 10**18; // 100 tokens
        uint256 ethAmount = 1 ether;
        governance.rewardArtist(artist, pointsAmount, ethAmount);

        // Verify balances
        assertEq(token.balanceOf(artist), pointsAmount, "Artist token balance incorrect");
        assertEq(artist.balance, ethAmount, "Artist ETH balance incorrect");
        assertEq(address(treasury).balance, 4 ether, "Treasury balance incorrect after reward");

        vm.stopPrank();
    }

    function testClaimReserveShare() public {
        vm.startPrank(owner);

        // Register artist and reward them
        governance.registerArtist(artist);

        // Add ETH to treasury
        vm.deal(owner, 10 ether);
        treasury.receiveRevenue{value: 5 ether}();

        // Add test contract as minter
        token.addMinter(address(this));

        // Warp time forward to bypass cooldown
        vm.warp(block.timestamp + 1 days);

        // Reward artist with tokens, but no ETH
        uint256 pointsAmount = 100 * 10**18; // 100 tokens
        governance.rewardArtist(artist, pointsAmount, 0);

        // Add more tokens to create a total supply
        vm.stopPrank();
        token.mint(address(this), 100 * 10**18);

        // Warp time forward to bypass cooldown
        vm.warp(block.timestamp + 30 days);

        // Set distribution ratio to 50%
        vm.prank(owner);
        treasury.setDistributionRatio(5000);

        // Artist claims their share of the reserve
        vm.startPrank(artist);
        uint256 initialBalance = artist.balance;
        treasury.claimReserveShare();

        // Artist should have received some ETH based on their token holdings
        assertTrue(artist.balance > initialBalance, "Artist didn't receive ETH from claiming");

        vm.stopPrank();
    }

    function testSubscriberGrowthValueRelationship() public {
        vm.startPrank(owner);

        // Register artist
        governance.registerArtist(artist);

        // Reward artist with initial subscribers
        uint256 initialReward = governance.calculateReward(50); // 50% contribution score

        // Add 100 subscribers
        for (uint i = 0; i < 100; i++) {
            governance.addSubscriber(address(uint160(100 + i)));
        }

        // Calculate new reward
        uint256 newReward = governance.calculateReward(50);

        // New reward should be larger as subscriber count increased
        assertTrue(newReward > initialReward, "Reward didn't increase with subscribers");

        vm.stopPrank();
    }

    function testUpgradeability() public {
        vm.startPrank(owner);

        // Deploy new token implementation
        PhloteToken newTokenImplementation = new PhloteToken();

        // Add test contract as minter
        token.addMinter(address(this));

        // Upgrade the proxy to the new implementation
        token.upgradeTo(address(newTokenImplementation));

        vm.stopPrank();

        // Try to use the token after upgrade
        token.mint(address(this), 100 * 10**18);
        assertEq(token.balanceOf(address(this)), 100 * 10**18, "Token functionality broken after upgrade");
    }
}
