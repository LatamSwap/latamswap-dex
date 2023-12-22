# LatamSwap: Revolutionizing DeFi

LatamSwap is a decentralized exchange (DEX), inspired by Uniswap v2 but with multiple optimizations for efficiency and lower gas costs. It's designed to offer a superior DeFi experience with full compatibility with Uniswap v2, along with a suite of enhanced features.

## Project Structure

The project is structured as follows:

- `src`: Contains the Solidity smart contracts that make up the core of LatamSwap.
  - `ERC1363.sol`: Implementation of the ERC1363 interface.
  - `Factory.sol`: Contract for the creation of new pairs.
  - `PairLibrary.sol`: Library for pair-related functionalities.
  - `PairV2.sol`: Enhanced pair contract compatible with Uniswap v2.
  - `Router.sol`: Main contract for interacting with the DEX.
  - `interfaces`: Directory for interface definitions.
    - `ILatamSwapRouter.sol`: Interface for LatamSwap router functionalities.
    - `IPairLatamSwap.sol`: Interface for LatamSwap pair functionalities.
    - `IUniswapV2Router02.sol`: Interface for Uniswap v2 router functionalities.
  - `utils`: Utility scripts and libraries.
    - `UQ112x112.sol`: Utility for fixed-point arithmetic.

## Getting Started

To get started with LatamSwap, clone the repository and install the necessary dependencies.

### Prerequisites

- foundry

### Installation

```bash
git clone https://github.com/[username]/latamswap.git
cd latamswap
forge install
```

### Running Tests

To run the tests, execute the following command:

```bash
forge test
```

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request
