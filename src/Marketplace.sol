// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
    bool private isLocked;
    // uint256 private itemLimit = 5;
    uint256 private constant pageSize = 50;

    // Maps an address to one of the following roles:
    //   - 0: unregistered users
    //   - 1: admin
    //   - 2: registered buyer
    //   - 3: registered seller
    //   - 4: registered buyer and seller
    mapping(address => uint8) private roles;

    // Maps an address to its balance in ETH
    mapping(address => uint256) private balances;

    // Maps an address to its number of listings
    // mapping(address => uint256) private numListings;


    // List of all items
    Item[] private items;

    constructor() {
        admin = msg.sender;
        roles[admin] = 1; // Admin role
        itemCounter = 0;
        isLocked = false;
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
        require(items[itemId - 1].owner == msg.sender, "Only item owner can edit this item");
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

    // Withdraw specified amount from the caller's marketplace account
    function withdraw(uint amount) public {
        require(roles[msg.sender] == 1 || roles[msg.sender] == 2 || roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered users can perform this action");
        require(amount <= balances[msg.sender], "Insufficient contract balance");

        require(isLocked == false, "Withdraw is currently locked");
        isLocked = true;

        balances[msg.sender]-=amount;
        // payable(msg.sender).transfer(amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        isLocked = false;
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

    // Relist existing item that has already been sold
    // function addExistingItem(string memory name, string memory description, uint256 price) public returns (bool) {
    //     require(roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered sellers can add items");

    //     // find the item that the owner of an item wants to 
    //     Item[] memory filteredItems = filterItems(name, description, address(0), msg.sender, price, price);

    //     require(filteredItems.length == 0, "No items were found");

    //     // take the first item by default (if there are multiple with the same exact specs)
    //     Item memory item = filteredItems[0];

    //     require(item.isSold == true, "The item has not been sold yet");

    //     item.seller = msg.sender;
    //     item.isSold = false;

    //     return true;
    // }
    
    // Overloaded addExistingItem function with itemId as the parameter instead
    function addExistingItem(uint256 itemId) public onlyItemOwner(itemId) returns (bool) {
        require(roles[msg.sender] == 3 || roles[msg.sender] == 4, "Only registered sellers can add items");

        Item storage item = items[itemId - 1];

        require(item.isSold == true, "The item has not been sold yet");

        item.seller = msg.sender;
        item.isSold = false;

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
    function viewItemsForSale(uint256 pageNumber) public view returns (Item[] memory) {
        uint256 startIndex = pageNumber * pageSize;
        uint256 endIndex = pageNumber * pageSize + (pageSize - 1);

        require(items.length > 0, "No listings exist");
        require(startIndex <= items.length - 1, "Page number is too large");

        if (endIndex > items.length - 1){
            endIndex = items.length - 1;
        }

        uint256 count = 0;
        for (uint256 i = startIndex; i < endIndex + 1; i++) {
            if (!items[i].isSold) {
                count++;
            }
        }

        Item[] memory itemsForSale = new Item[](count);
        uint256 index = 0;
        for (uint256 i = startIndex; i < endIndex + 1; i++) {
            if (!items[i].isSold) {
                itemsForSale[index] = items[i];
                index++;
            }
        }

        return itemsForSale;
    }

    // Filter all items
    // function filterItems(string memory name, string memory description, address seller, address owner, uint256 minPrice, uint256 maxPrice, uint256 pageNumber) public view onlyRegisteredUserAndAdmin returns (Item[] memory) {        
    //     require(minPrice <= maxPrice, "min price must be less than max price");
        
    //     Item[] memory filteredItems = viewAllItems();

    //     if (bytes(name).length > 0){
    //         filteredItems = filterItemsByName(filteredItems, name, pageNumber);
    //     }

    //     if (bytes(description).length > 0){
    //         filteredItems = filterItemsByDescription(filteredItems, description, pageNumber);
    //     }
        
    //     if (seller != address(0)){
    //         filteredItems = filterItemsBySeller(filteredItems, seller, pageNumber);
    //     }

    //     if (owner != address(0)){
    //         filteredItems = filterItemsBySeller(filteredItems, owner, pageNumber);
    //     }

    //     filteredItems = filterItemsByPrice(filteredItems, minPrice, maxPrice, pageNumber);

    //     return filteredItems;
    // }

    // Filter items for sale
    function filterItemsForSale(string memory name, string memory description, address seller, /*address owner,*/ uint256 minPrice, uint256 maxPrice, uint256 pageNumber) public view onlyRegisteredUserAndAdmin returns (Item[] memory) {        
        require(minPrice <= maxPrice, "min price must be less than max price");
        
        Item[] memory filteredItemsForSale = viewItemsForSale(pageNumber);

        if (bytes(name).length > 0){
            filteredItemsForSale = filterItemsByName(filteredItemsForSale, name);
        }

        if (bytes(description).length > 0){
            filteredItemsForSale = filterItemsByDescription(filteredItemsForSale, description);
        }
        
        if (seller != address(0)){
            filteredItemsForSale = filterItemsBySeller(filteredItemsForSale, seller);
        }

        // if (owner != address(0)){
        //     filteredItems = filterItemsBySeller(filteredItems, owner);
        // }

        filteredItemsForSale = filterItemsByPrice(filteredItemsForSale, minPrice, maxPrice);

        return filteredItemsForSale;
    }

    // Filter items by owner
    function filterItemsByOwner(Item[] memory itemsToFilter, address owner) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (itemsToFilter[i].owner == owner) {
                count++;
            }
        }
        
        Item[] memory filteredItems = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (itemsToFilter[i].owner == owner) {
                filteredItems[index] = itemsToFilter[i];
                index++;
            }
        }

        return filteredItems;
    }

    // Filter items by seller
    function filterItemsBySeller(Item[] memory itemsToFilter, address seller) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (itemsToFilter[i].seller == seller) {
                count++;
            }
        }
        
        Item[] memory filteredItems = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (itemsToFilter[i].seller == seller) {
                filteredItems[index] = itemsToFilter[i];
                index++;
            }
        }

        return filteredItems;
    }

    // Filter items by name
    function filterItemsByName(Item[] memory itemsToFilter, string memory name) public view returns (Item[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (keccak256(bytes(itemsToFilter[i].name)) == keccak256(bytes(name))) {
                count++;
            }
        }
        
        Item[] memory filteredItems = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (keccak256(bytes(itemsToFilter[i].name)) == keccak256(bytes(name))) {
                filteredItems[index] = itemsToFilter[i];
                index++;
            }
        }

        return filteredItems;
    }

    // Filter items by description
    function filterItemsByDescription(Item[] memory itemsToFilter, string memory description) public view returns (Item[] memory) {  
        uint256 count = 0;
        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (keccak256(bytes(itemsToFilter[i].description)) == keccak256(bytes(description))) {
                count++;
            }
        }
        
        Item[] memory filteredItems = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (keccak256(bytes(itemsToFilter[i].description)) == keccak256(bytes(description))) {
                filteredItems[index] = itemsToFilter[i];
                index++;
            }
        }

        return filteredItems;
    }

    // Filter items by price
    function filterItemsByPrice(Item[] memory itemsToFilter, uint256 minPrice, uint256 maxPrice) public view returns (Item[] memory) {    
        uint256 count = 0;
        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (itemsToFilter[i].price >= minPrice && itemsToFilter[i].price <= maxPrice) {
                count++;
            }
        }

        Item[] memory filteredItems = new Item[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < itemsToFilter.length; i++) {
            if (itemsToFilter[i].price >= minPrice && itemsToFilter[i].price <= maxPrice) {
                filteredItems[index] = itemsToFilter[i];
                index++;
            }
        }

        return filteredItems;
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

    // Returns the balance of a user
    function getBalance() public view returns (uint256) {
        return msg.sender.balance;
    }
}
