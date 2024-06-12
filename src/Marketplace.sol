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
    event ItemEdited(uint256 id, string name, string description, uint256 price);

    // Modifier: limits access to admins
    modifier onlyAdmin() {
        require(roles[msg.sender] == 1, "Only admin can perform this action");
        _;
    }

    // Modifier: limits access to registered users
    modifier onlyRegisteredUser() {
        require(roles[msg.sender] == 2 || roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered users can perform this action");
        _;
    }

    // Modifier: limits access to registered users and admins
    modifier onlyRegisteredUserAndAdmin() {
        require(roles[msg.sender] == 1 || roles[msg.sender] == 2 || roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered users and admins can perform this action");
        _;
    }

    // Modifier: limits access to owner of the item
    modifier onlyItemOwner(uint256 itemId) {
        require(itemId > 0 && itemId <= itemCounter, "Invalid item ID");
        require(items[itemId - 1].seller == msg.sender, "Only item owner can edit this item");
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

    // Check the role of the caller
    function viewRole() public view returns (uint8) {
        return roles[msg.sender];
    }

    // Add balance to the caller's account
    function addBalance() public payable onlyRegisteredUser returns (bool) {
        balances[msg.sender] += msg.value;
        return true;
    }

    function withdraw(uint amount) public {
        // require(msg.sender == owner, "Only the owner can withdraw funds");
        require(roles[msg.sender] == 1 || roles[msg.sender] == 2 || roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered users can perform this action");
        require(amount <= balances[msg.sender], "Insufficient contract balance");

        balances[msg.sender]-=amount;
        payable(msg.sender).transfer(amount);
    }

    // Return the balance of ETH deposited to the marketplace by the caller
    function viewBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    // Add an item to the marketplace registry for sale
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
            owner: msg.sender,
            isSold: false
        });

        items.push(newItem);
        emit ItemAdded(itemCounter, msg.sender, name, price);
        return true;
    }

    // Edit an item in the marketplace registry
    // Only the owner of the item can edit it
    // Can be used to update name, description, and price
    // Can also be used to relist an item that has been sold as for sale
    function editItem(uint256 itemId, string memory name, string memory description, uint256 price) public onlyItemOwner(itemId) returns (bool) {
        Item storage item = items[itemId - 1];
        item.name = name;
        item.description = description;
        item.price = price;
        emit ItemEdited(itemId, name, description, price);
        return true;
    }

    // View all items (including ones that have been sold)
    function viewAllItems() public view returns (Item[] memory) {
        return items;
    }

    // View items that, filtered by items that are still for sale
    function viewItemsForSale() public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (!items[i].isSold) {
                count++;
            }
        }

        Item[] memory itemsForSale = new Item[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (!items[i].isSold) {
                itemsForSale[index] = items[i];
                index++;
            }
        }

        return itemsForSale;
    }

    // Filter items
    function filterItemsForSale(string memory name, string memory description, address seller, uint256 minPrice, uint256 maxPrice) public view onlyRegisteredUserAndAdmin returns (Item[] memory) {        
        require(minPrice < maxPrice, "min price must be less than max price");
        
        Item[] memory filteredItemsForSale = viewItemsForSale();

        if (bytes(name).length > 0){
            filteredItemsForSale = filterItemsForSalebyName(filteredItemsForSale, name);
        }

        if (bytes(description).length > 0){
            filteredItemsForSale = filterItemsForSalebyDescription(filteredItemsForSale, description);
        }
        
        if (seller != address(0)){
            filteredItemsForSale = filterItemsForSalebySeller(filteredItemsForSale, seller);
        }

        filteredItemsForSale = filterItemsForSalebyPrice(filteredItemsForSale, minPrice, maxPrice);

        return filteredItemsForSale;
    }

    function filterItemsForSalebySeller(Item[] memory itemsForSale, address seller) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (itemsForSale[i].seller == seller) {
                count++;
            }
        }
        
        Item[] memory filteredItemsForSale = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (itemsForSale[i].seller == seller) {
                filteredItemsForSale[index] = itemsForSale[i];
                index++;
            }
        }

        return filteredItemsForSale;
    }

    function filterItemsForSalebyName(Item[] memory itemsForSale, string memory name) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (keccak256(bytes(itemsForSale[i].name)) == keccak256(bytes(name))) {
                count++;
            }
        }
        
        Item[] memory filteredItemsForSale = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (keccak256(bytes(itemsForSale[i].name)) == keccak256(bytes(name))) {
                filteredItemsForSale[index] = itemsForSale[i];
                index++;
            }
        }

        return filteredItemsForSale;
    }

    function filterItemsForSalebyDescription(Item[] memory itemsForSale, string memory description) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (keccak256(bytes(itemsForSale[i].description)) == keccak256(bytes(description))) {
                count++;
            }
        }
        
        Item[] memory filteredItemsForSale = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (keccak256(bytes(itemsForSale[i].description)) == keccak256(bytes(description))) {
                filteredItemsForSale[index] = itemsForSale[i];
                index++;
            }
        }

        return filteredItemsForSale;
    }

    function filterItemsForSalebyPrice(Item[] memory itemsForSale, uint256 minPrice, uint256 maxPrice) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (itemsForSale[i].price >= minPrice && itemsForSale[i].price <= maxPrice) {
                count++;
            }
        }

        Item[] memory filteredItemsForSale = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsForSale.length; i++) {
            if (itemsForSale[i].price >= minPrice && itemsForSale[i].price <= maxPrice) {
                filteredItemsForSale[index] = itemsForSale[i];
                index++;
            }
        }

        return filteredItemsForSale;
    }

    // Buy an item, transferring ownership and updating balances
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

    function getBalance() public view returns (uint256) {
        return msg.sender.balance;
    }
}
