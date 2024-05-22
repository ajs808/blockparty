// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Marketplace {
    // Struct to represent an item
    struct Item {
        uint256 id;
        string name;
        string description;
        uint256 price;
        address seller;
        address owner;
        bool isSold;
    }

    address private admin;
    uint256 private itemCounter;

    // Maps an address to one of the following roles:
    //   - 0: unregistered users
    //   - 1: admin
    //   - 2: registered buyer
    //   - 3: registered seller
    //   - 4: registered buyer and seller
    mapping(address => uint8) private roles;

    // Maps an address to its balance in ETH
    mapping(address => uint256) private balances;

    // List of all items
    Item[] private items;

    constructor() {
        admin = msg.sender;
        roles[admin] = 1; // Admin role
    }

    // Events
    event ItemAdded(uint256 indexed itemId, address indexed seller, string name, uint256 price);
    event ItemSold(uint256 indexed itemId, address indexed buyer);

    // Modifier to check admin role
    modifier onlyAdmin() {
        require(roles[msg.sender] == 1, "Only admin can perform this action");
        _;
    }

    // Modifier to check registered user
    modifier onlyRegisteredUser() {
        require(roles[msg.sender] == 2 || roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered users can perform this action");
        _;
    }

    // Register a user as a buyer
    function registerBuyer() public returns (bool) {
        require(roles[msg.sender] == 0 || roles[msg.sender] == 3, "User already registered as buyer or both");
        if (roles[msg.sender] == 0) {
            roles[msg.sender] = 2;
        } else {
            roles[msg.sender] = 4;
        }
        return true;
    }

    // Register a user as a seller
    function registerSeller() public returns (bool) {
        require(roles[msg.sender] == 0 || roles[msg.sender] == 2, "User already registered as seller or both");
        if (roles[msg.sender] == 0) {
            roles[msg.sender] = 3;
        } else {
            roles[msg.sender] = 4;
        }
        return true;
    }

    // Add balance to the caller's account
    function addBalance() public payable onlyRegisteredUser returns (bool) {
        balances[msg.sender] += msg.value;
        return true;
    }

    // Check the balance of the caller
    function viewBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    // Add an item for sale
    function addItem(string memory name, string memory description, uint256 price) public returns (bool) {
        require(roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered sellers can add items");
        require(price > 0, "Price must be greater than zero");

        itemCounter++;
        Item memory newItem = Item({
            id: itemCounter,
            name: name,
            description: description,
            price: price,
            seller: msg.sender,
            owner: address(0),
            isSold: false
        });

        items.push(newItem);
        emit ItemAdded(itemCounter, msg.sender, name, price);
        return true;
    }

    // View all items for sale
    function viewItems() public view returns (Item[] memory) {
        return items;
    }

    // Buy an item
    function buyItem(uint256 itemId) public returns (bool) {
        require(roles[msg.sender] == 2 || roles[msg.sender] == 4, "Only registered buyers can buy items");
        require(itemId > 0 && itemId <= itemCounter, "Invalid item ID");
        Item storage item = items[itemId - 1];
        require(!item.isSold, "Item already sold");
        require(balances[msg.sender] >= item.price, "Insufficient balance");

        balances[msg.sender] -= item.price;
        balances[item.seller] += item.price;
        item.owner = msg.sender;
        item.isSold = true;

        emit ItemSold(itemId, msg.sender);
        return true;
    }

    // Check the role of the caller
    function viewRole() public view returns (uint8) {
        return roles[msg.sender];
    }
}