# Blockparty Marketplace

## Overview

Blockparty is a decentralized marketplace built on blockchain technology in Solidity. It allows users to buy and sell items securely using Ether (ETH). This document outlines the API, setup instructions, component descriptions, and user roles for the marketplace.

## Setup Instructions

### Foundry Overview

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

### Foundry Documentation

https://book.getfoundry.sh/

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## API Documentation

### Register Buyer
Registers the caller as a buyer.

- **Endpoint:** `registerBuyer()`
- **Returns:** `bool`
- **Notes:** 
  - Can be called by unregistered users or registered sellers.
  - Users already registered as buyers or both buyers and sellers cannot call this function.

### Register Seller
Registers the caller as a seller.

- **Endpoint:** `registerSeller()`
- **Returns:** `bool`
- **Notes:** 
  - Can be called by unregistered users or registered buyers.
  - Users already registered as sellers or both buyers and sellers cannot call this function.

### View Role
Returns the role of the caller.

- **Endpoint:** `viewRole()`
- **Returns:** `uint8`
  - `0`: Unregistered user
  - `1`: Admin
  - `2`: Registered buyer
  - `3`: Registered seller
  - `4`: Registered buyer and seller

### Add Balance
Adds ETH to the caller's balance in the marketplace.

- **Endpoint:** `addBalance()`
- **Returns:** `bool`
- **Notes:** 
  - Only registered users can call this function.

### Withdraw
Withdraws a specified amount of ETH from the caller's marketplace balance.

- **Endpoint:** `withdraw(uint amount)`
- **Notes:** 
  - Only registered users can call this function.
  - The withdraw function is protected by a reentrancy guard.

### View Balance
Returns the ETH balance of the caller in the marketplace.

- **Endpoint:** `viewBalance()`
- **Returns:** `uint256`

### Add Item
Adds a new item to the marketplace for sale.

- **Endpoint:** `addItem(string memory name, string memory description, uint256 price)`
- **Returns:** `bool`
- **Notes:** 
  - Only registered sellers can call this function.

### Add Existing Item
Re-lists an item that has been sold back to the marketplace.

- **Endpoint:** `addExistingItem(uint256 itemId)`
- **Returns:** `bool`
- **Notes:** 
  - Only the owner of the item can call this function.

### Edit Item
Edits an item in the marketplace registry.

- **Endpoint:** `editItem(uint256 itemId, string memory name, string memory description, uint256 price)`
- **Returns:** `bool`
- **Notes:** 
  - Only the owner of the item can call this function.

### View All Items
Returns all items in the marketplace, including sold items.

- **Endpoint:** `viewAllItems()`
- **Returns:** `Item[]`

### View Items For Sale
Returns items that are currently for sale, paginated.

- **Endpoint:** `viewItemsForSale(uint256 pageNumber)`
- **Returns:** `Item[]`

### Filter Items For Sale
Filters items for sale based on provided criteria.

- **Endpoint:** `filterItemsForSale(string memory name, string memory description, address seller, uint256 minPrice, uint256 maxPrice, uint256 pageNumber)`
- **Returns:** `Item[]`

### Buy Item
Buys an item from the marketplace.

- **Endpoint:** `buyItem(uint256 itemId)`
- **Returns:** `bool`
- **Notes:** 
  - Only registered buyers can call this function.

### Get Balance
Returns the ETH balance of the caller.

- **Endpoint:** `getBalance()`
- **Returns:** `uint256`

## User Roles

### Admin
- Can view and manage all aspects of the marketplace.

### Registered Buyer
- Can view items for sale.
- Can purchase items.
- Can add balance and withdraw funds.

### Registered Seller
- Can list items for sale.
- Can edit their listed items.
- Can re-list sold items.

### Registered Buyer and Seller
- Can perform actions of both buyers and sellers.

### Unregistered User
- Can register as a buyer or seller.

## Security Notes
- Functions that modify state or involve transfers are protected by appropriate modifiers.
- Reentrancy attacks are mitigated by using a reentrancy guard in the `withdraw` function.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

