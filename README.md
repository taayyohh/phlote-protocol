# Phlote Protocol

This repository contains the upgradeable smart contracts implementing the Phlote.xyz decentralized business model. The model operates as follows:

1. A portion of Phlote.xyz subscription revenues are captured into a reserve.
2. Phlote tokens ("Points") have a claim on these reserves.
3. Points can only be earned by artists via Phlote.xyz.
4. The larger the subscriber base, the larger the reserve, and the more valuable Points become.

## Project Structure

- `PhloteToken.sol`: An upgradeable ERC20 token representing "Points" in the Phlote ecosystem
- `PhloteTreasury.sol`: Upgradeable contract that holds the reserve funds from subscription revenues
- `PhloteGovernance.sol`: Upgradeable contract that manages the distribution of Points to artists
- `PhloteFactory.sol`: Contract to deploy the entire ecosystem in one transaction with upgradeable proxies

## Upgradeability

The contracts use OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) pattern, allowing for future upgrades while maintaining the same contract addresses and state.

Key points:
- All contracts can be upgraded by their respective owners
- The upgrade process uses the `upgradeToAndCall` function
- Each contract's logic can be upgraded independently of the others

## Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd phlote-contracts

# Install dependencies
forge install
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

## Testing

Run the tests to verify everything is working as expected:

```bash
forge test -vv
```

## Deployment

### Configuration

Create a `.env` file with your private key:

```bash
echo "PRIVATE_KEY=your_private_key_here" > .env
```

### Deploy to Base Sepolia

```bash
# Load environment variables
source .env

# Deploy the contracts
forge script script/DeployPhlote.s.sol:DeployPhlote --rpc-url https://sepolia.base.org --broadcast --verify
```

## Smart Contract Architecture

### PhloteToken

This is an upgradeable ERC20 token contract that represents "Points" in the Phlote ecosystem. Points are minted to artists as rewards for their contributions.

Features:
- Standard ERC20 functionality
- Only authorized minters can create new tokens
- Burning capability for future tokenomics
- Upgradeable using UUPS pattern

### PhloteTreasury

This upgradeable contract holds the reserve funds from subscription revenues. Points holders can claim their share of the reserve.

Features:
- Receives and holds subscription revenues
- Allows Points holders to claim their share based on token holdings
- Distributes rewards to artists via the Governance contract
- Upgradeable using UUPS pattern

### PhloteGovernance

This upgradeable contract manages the distribution of Points to artists and the relationship between subscriber growth and token value.

Features:
- Registers artists in the ecosystem
- Tracks subscribers
- Calculates and distributes rewards to artists
- Reward amount increases with subscriber count
- Upgradeable using UUPS pattern

## Usage Examples

### Register an Artist

```solidity
// As the contract owner or operator
governance.registerArtist(artistAddress);
```

### Add a Subscriber

```solidity
// As the contract owner or operator
governance.addSubscriber(subscriberAddress);
```

### Reward an Artist

```solidity
// As the contract owner or operator
uint256 pointsAmount = 100 * 10**18; // 100 tokens
uint256 ethAmount = 1 ether;
governance.rewardArtist(artistAddress, pointsAmount, ethAmount);
```

### Claim Reserve Share

```solidity
// As a Points holder
treasury.claimReserveShare();
```

### Upgrading Contracts

To upgrade a contract, deploy a new implementation and then:

```solidity
// As the contract owner
tokenContract.upgradeToAndCall(newImplementationAddress, "");
```

## License

MIT
