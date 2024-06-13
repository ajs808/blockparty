// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "../src/Marketplace.sol";

// Used for reentrancy testing
contract Reentrancy_Attack {
    Marketplace public marketplace;
    uint256 public amount;

    constructor(Marketplace _marketplace) {
        marketplace = _marketplace;
    }

    receive() external payable {
        if (address(marketplace).balance >= amount) {
            marketplace.withdraw(amount);
        }
    }

    function attack() external payable {
        amount = msg.value;
        marketplace.addBalance{value: amount}();
        marketplace.withdraw(amount);
    }

    function getBalance() public view returns (uint256) {
        return msg.sender.balance;
    }
}

// Used for selfdestruct testing
contract Selfdestruct_Attack {
    Marketplace public marketplace;
    uint256 public amount;

    constructor(Marketplace _marketplace) {
        marketplace = _marketplace;
    }

    function attack() external payable {
        selfdestruct(payable(address(marketplace)));
    }

    function getBalance() public view returns (uint256) {
        return msg.sender.balance;
    }
}

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    Reentrancy_Attack public reentrancy_attacker;
    Selfdestruct_Attack public selfdestruct_attacker;

    address public admin = address(0x01);
    address public user1 = address(0x02);
    address public user2 = address(0x03);
    address public user3 = address(0x04);

    // ** FUNCTIONAL TESTING **

    function setUp() public {
        vm.startPrank(admin);
        marketplace = new Marketplace();
        reentrancy_attacker = new Reentrancy_Attack(marketplace);
        selfdestruct_attacker = new Selfdestruct_Attack(marketplace);
        vm.stopPrank();
    }

    //register as buyer
    function test_registerBuyer() public {
        vm.startPrank(user1);
        assertEq(marketplace.registerBuyer(), true);
        assertEq(marketplace.viewRole(), 2);
        vm.stopPrank();
    }

    //register as seller
    function test_registerSeller() public {
        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        assertEq(marketplace.viewRole(), 3);
        vm.stopPrank();
    }

    //register as both buyer and seller
    function test_registerAsBoth() public {
        vm.startPrank(user1);
        assertEq(marketplace.registerBuyer(), true);
        assertEq(marketplace.registerSeller(), true);
        assertEq(marketplace.viewRole(), 4);
        vm.stopPrank();
    }

    //test deposit of ETH into marketplace account
    function test_addBalance() public {
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        marketplace.registerBuyer();
        assertEq(marketplace.viewBalance(), 0 ether);
        marketplace.addBalance{value: 0.5 ether}();
        assertEq(marketplace.viewBalance(), 0.5 ether);
        vm.stopPrank();
    }

    //test withdraw of ETH into marketplace account
    function test_withdraw() public {
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        marketplace.registerBuyer();
        assertEq(marketplace.viewBalance(), 0 ether);
        marketplace.addBalance{value: 0.5 ether}();
        assertEq(marketplace.viewBalance(), 0.5 ether);
        marketplace.withdraw(0.5 ether);
        assertEq(marketplace.viewBalance(), 0 ether);
        assertEq(user1.balance, 1 ether);
        vm.stopPrank();
    }

    //test adding item to registry
    function test_addItem() public {
        vm.startPrank(user1);
        marketplace.registerSeller();
        assertEq(marketplace.addItem("Item1", "Description1", 1 ether), true);
        Marketplace.Item[] memory items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].name, "Item1");
        assertEq(items[0].description, "Description1");
        assertEq(items[0].price, 1 ether);
        assertEq(items[0].seller, user1);
        assertEq(items[0].owner, user1);
        assertEq(items[0].isSold, false);
        Marketplace.Item[] memory itemsForSale = marketplace.viewItemsForSale(0);
        assertEq(itemsForSale.length, 1);
        vm.stopPrank();
    }

    //unregistered user cannot add item
    function test_addItem_unregistered() public {
        vm.startPrank(user1);
        vm.expectRevert("Only registered sellers can add items");
        marketplace.addItem("Item1", "Description1", 1 ether);
        vm.stopPrank();
    }

    //test adding item with invalid price
    function test_addItem_invalidPrice() public {
        vm.startPrank(user1);
        marketplace.registerSeller();
        vm.expectRevert("Price must be greater than zero");
        marketplace.addItem("Item1", "Description1", 0 ether);
        vm.stopPrank();
    }

    //test viewing items
    function test_viewAllItems() public {
        vm.startPrank(user1);
        marketplace.registerSeller();
        marketplace.addItem("Item1", "Description1", 1 ether);
        marketplace.addItem("Item2", "Description2", 2 ether);
        Marketplace.Item[] memory items = marketplace.viewAllItems();
        assertEq(items.length, 2);
        assertEq(items[0].name, "Item1");
        assertEq(items[1].name, "Item2");
        vm.stopPrank();
    }

    //test purchase item and transfer of ETH
    function test_buyItem() public {
        vm.deal(user2, 1 ether);

        vm.startPrank(user1);
        marketplace.registerSeller();
        marketplace.addItem("Item1", "Description1", 1 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        marketplace.registerBuyer();
        marketplace.addBalance{value: 1 ether}();
        assertEq(marketplace.buyItem(1), true);
        assertEq(marketplace.viewBalance(), 0 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        assertEq(marketplace.viewBalance(), 1 ether);
        Marketplace.Item[] memory items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].isSold, true);
        assertEq(items[0].owner, user2);
        Marketplace.Item[] memory itemsForSale = marketplace.viewItemsForSale(0);
        assertEq(itemsForSale.length, 0);
        vm.stopPrank();
    }

    // Test editItem
    function test_editItem() public {
        vm.startPrank(user1);
        marketplace.registerSeller();
        marketplace.addItem("Item1", "Description1", 1 ether);
        vm.stopPrank();

        // Verify the initial item details
        Marketplace.Item[] memory items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].name, "Item1");
        assertEq(items[0].description, "Description1");
        assertEq(items[0].price, 1 ether);
        assertEq(items[0].seller, user1);
        assertEq(items[0].isSold, false);

        // Try to edit item by non-owner (should fail)
        vm.startPrank(user2);
        vm.expectRevert("Only item owner can edit this item");
        marketplace.editItem(1, "NewItem1", "NewDescription1", 2 ether);
        vm.stopPrank();

        // Edit item by owner
        vm.startPrank(user1);
        assertEq(marketplace.editItem(1, "NewItem1", "NewDescription1", 2 ether), true);
        vm.stopPrank();

        // Verify the updated item details
        items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].name, "NewItem1");
        assertEq(items[0].description, "NewDescription1");
        assertEq(items[0].price, 2 ether);
        assertEq(items[0].seller, user1);
        assertEq(items[0].isSold, false);
    }

    // Test filtering by name
    function test_filterItemsByName() public {

        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(marketplace.registerBuyer(), true);
        vm.stopPrank();

        vm.startPrank(user3);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        // testing for the seller
        vm.startPrank(user1);

        marketplace.addItem("Item1", "Description1", 1 ether);
        marketplace.addItem("Item2", "Description2", 2 ether);

        vm.stopPrank();

        vm.startPrank(user3);

        marketplace.addItem("Item3", "Description3", 3 ether);
        marketplace.addItem("Item4", "Description4", 4 ether);
        marketplace.addItem("Item5", "Description5", 5 ether);

        vm.stopPrank();

        vm.startPrank(user1);

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("Item1", "", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item1");

        filteredItems = marketplace.filterItemsForSale("Item4", "", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item4");

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSale("Item1", "", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item1");

        filteredItems = marketplace.filterItemsForSale("Item4", "", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item4");

        vm.stopPrank();

    }

    // Test filtering by description
    function test_filterItemsByDescription() public {

        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(marketplace.registerBuyer(), true);
        vm.stopPrank();

        vm.startPrank(user3);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        // testing for the seller
        vm.startPrank(user1);

        marketplace.addItem("Item1", "Description1", 1 ether);
        marketplace.addItem("Item2", "Description2", 2 ether);

        vm.stopPrank();

        vm.startPrank(user3);

        marketplace.addItem("Item3", "Description3", 3 ether);
        marketplace.addItem("Item4", "Description4", 4 ether);
        marketplace.addItem("Item5", "Description5", 5 ether);

        vm.stopPrank();

        vm.startPrank(user1);

        Marketplace.Item[] memory items = marketplace.viewAllItems();

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("", "Description1", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description1");

        filteredItems = marketplace.filterItemsForSale("", "Description4", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description4");

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSale("", "Description1", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description1");

        filteredItems = marketplace.filterItemsForSale("", "Description4", address(0), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description4");

        vm.stopPrank();

    }

    // Test filtering by seller
    function test_filterItemsBySeller() public {

        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(marketplace.registerBuyer(), true);
        vm.stopPrank();

        vm.startPrank(user3);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        // testing for the seller
        vm.startPrank(user1);

        marketplace.addItem("Item1", "Description1", 1 ether);
        marketplace.addItem("Item2", "Description2", 2 ether);

        vm.stopPrank();

        vm.startPrank(user3);

        marketplace.addItem("Item3", "Description3", 3 ether);
        marketplace.addItem("Item4", "Description4", 4 ether);
        marketplace.addItem("Item5", "Description5", 5 ether);

        vm.stopPrank();

        vm.startPrank(user1);

        Marketplace.Item[] memory items = marketplace.viewAllItems();

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("", "", address(user1), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 2);
        assertEq(filteredItems[0].seller, address(user1));
        assertEq(filteredItems[1].seller, address(user1));

        filteredItems = marketplace.filterItemsForSale("", "", address(user3), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].seller, address(user3));
        assertEq(filteredItems[1].seller, address(user3));
        assertEq(filteredItems[2].seller, address(user3));

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSale("", "", address(user1), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 2);
        assertEq(filteredItems[0].seller, address(user1));
        assertEq(filteredItems[1].seller, address(user1));

        filteredItems = marketplace.filterItemsForSale("", "", address(user3), 0 ether, 100 ether, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].seller, address(user3));
        assertEq(filteredItems[1].seller, address(user3));
        assertEq(filteredItems[2].seller, address(user3));

        vm.stopPrank();
    }

    // Test filtering by price
    function test_filterItemsByPrice() public {

        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(marketplace.registerBuyer(), true);
        vm.stopPrank();

        vm.startPrank(user3);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user1);

        marketplace.addItem("Item1", "Description1", 1);
        marketplace.addItem("Item2", "Description2", 2);

        vm.stopPrank();

        vm.startPrank(user3);

        marketplace.addItem("Item3", "Description3", 3);
        marketplace.addItem("Item4", "Description4", 4);
        marketplace.addItem("Item5", "Description5", 5);

        vm.stopPrank();

        // testing for the seller
        vm.startPrank(user1);

        Marketplace.Item[] memory items = marketplace.viewAllItems();

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("", "", address(0), 1, 3, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].price, 1);
        assertEq(filteredItems[1].price, 2);
        assertEq(filteredItems[2].price, 3);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 2, 5, 0);
        assertEq(filteredItems.length, 4);
        assertEq(filteredItems[0].price, 2);
        assertEq(filteredItems[1].price, 3);
        assertEq(filteredItems[2].price, 4);
        assertEq(filteredItems[3].price, 5);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 3, 3, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].price, 3);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 0, 100, 0);
        assertEq(filteredItems.length, 5);
        assertEq(filteredItems[0].price, 1);
        assertEq(filteredItems[1].price, 2);
        assertEq(filteredItems[2].price, 3);
        assertEq(filteredItems[3].price, 4);
        assertEq(filteredItems[4].price, 5);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 0, 0, 0);
        assertEq(filteredItems.length, 0);

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 1, 3, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].price, 1);
        assertEq(filteredItems[1].price, 2);
        assertEq(filteredItems[2].price, 3);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 2, 5, 0);
        assertEq(filteredItems.length, 4);
        assertEq(filteredItems[0].price, 2);
        assertEq(filteredItems[1].price, 3);
        assertEq(filteredItems[2].price, 4);
        assertEq(filteredItems[3].price, 5);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 3, 3, 0);
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].price, 3);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 0, 100, 0);
        assertEq(filteredItems.length, 5);
        assertEq(filteredItems[0].price, 1);
        assertEq(filteredItems[1].price, 2);
        assertEq(filteredItems[2].price, 3);
        assertEq(filteredItems[3].price, 4);
        assertEq(filteredItems[4].price, 5);

        filteredItems = marketplace.filterItemsForSale("", "", address(0), 0, 0, 0);
        assertEq(filteredItems.length, 0);

        vm.stopPrank();
    }

    // Test general filtering
    function test_filterItemsForSale() public {
        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(marketplace.registerBuyer(), true);
        vm.stopPrank();

        vm.startPrank(user3);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user1);

        marketplace.addItem("Item1", "Description1", 1);
        marketplace.addItem("Item9", "Description1", 8);
        marketplace.addItem("Item9", "Description1", 10);
        marketplace.addItem("Item2", "Description2", 2);

        vm.stopPrank();

        vm.startPrank(user3);

        marketplace.addItem("Item9", "Description4", 10);
        marketplace.addItem("Item3", "Description3", 3);
        marketplace.addItem("Item4", "Description4", 4);
        marketplace.addItem("Item5", "Description5", 5);

        vm.stopPrank();

        // testing for the seller
        vm.startPrank(user1);

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("", "", address(0), 1, 3, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].price, 1);
        assertEq(filteredItems[1].price, 2);
        assertEq(filteredItems[2].price, 3);

        filteredItems = marketplace.filterItemsForSale("Item9", "", address(0), 1, 100, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].price, 8);
        assertEq(filteredItems[0].name, "Item9");
        assertEq(filteredItems[1].price, 10);
        assertEq(filteredItems[1].name, "Item9");
        assertEq(filteredItems[2].price, 10);
        assertEq(filteredItems[2].name, "Item9");

        filteredItems = marketplace.filterItemsForSale("", "Description4", address(0), 1, 100, 0);
        assertEq(filteredItems.length, 2);
        assertEq(filteredItems[0].price, 10);
        assertEq(filteredItems[0].name, "Item9");
        assertEq(filteredItems[1].price, 4);
        assertEq(filteredItems[1].name, "Item4");

        vm.stopPrank();
    }

    // ** SECURITY TESTING **

    // * Reentrancy testing *
    // test_reentrancy1, test_reentrancy2, test_reentrancy3, and test_reentrancy4 test for a reentrancy attack on the withdraw function of our Marketplace smart contract
    // Each successive test tests on increasing amounts of ether that the attacker tries to withdraw
    // A potential damage of reentrancy is that an attacker can withdraw more ether than they've deposited in the Marketplace smart contract
    function test_reentrancy1() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(reentrancy_attacker), 2 ether);
        vm.startPrank(address(reentrancy_attacker));
        marketplace.registerSeller();
        reentrancy_attacker.attack{value: 1 ether}();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = reentrancy_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 2 ether);
    }

    function test_reentrancy2() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(reentrancy_attacker), 20 ether);
        vm.startPrank(address(reentrancy_attacker));
        marketplace.registerSeller();
        reentrancy_attacker.attack{value: 5 ether}();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = reentrancy_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 20 ether);
    }

    function test_reentrancy3() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(reentrancy_attacker), 2000 ether);
        vm.startPrank(address(reentrancy_attacker));
        marketplace.registerSeller();
        reentrancy_attacker.attack{value: 1000 ether}();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = reentrancy_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 2000 ether);
    }

    function test_reentrancy4() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(reentrancy_attacker), 1000000 ether);
        vm.startPrank(address(reentrancy_attacker));
        marketplace.registerSeller();
        reentrancy_attacker.attack{value: 1000000 ether}();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = reentrancy_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 1000000 ether);
    }

    // * Selfdestruct testing *
    // test_selfdestruct1, test_selfdestruct2, test_selfdestruct3, and test_selfdestruct4 test whether self-destructing an attacker contract will affect the Marketplace smart contract
    // After calling selfdestruct, each test runs a simple use case of the smart contract to see if it has been impacted by selfdestruct
    // selfdestruct sends all of the ether stored in the destructed contract to the recipient contract
    // however, the Marketplace contract does not use its own balance in any operation, so it does not affect the contract's functionality
    function test_selfdestruct1() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(selfdestruct_attacker), 999999 ether);
        vm.startPrank(address(selfdestruct_attacker));
        marketplace.registerSeller();
        selfdestruct_attacker.attack();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = selfdestruct_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 0 ether);
        assertEq(address(marketplace).balance, 999999 ether);

        // simple use case to show that selfdestruct will not affect the functionality smart contract
        vm.deal(user2, 1 ether);

        vm.startPrank(user1);
        marketplace.registerSeller();
        marketplace.addItem("Item1", "Description1", 1 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        marketplace.registerBuyer();
        marketplace.addBalance{value: 1 ether}();
        assertEq(marketplace.buyItem(1), true);
        assertEq(marketplace.viewBalance(), 0 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        assertEq(marketplace.viewBalance(), 1 ether);
        Marketplace.Item[] memory items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].isSold, true);
        assertEq(items[0].owner, user2);
        Marketplace.Item[] memory itemsForSale = marketplace.viewItemsForSale(0);
        assertEq(itemsForSale.length, 0);
        vm.stopPrank();
    }

    function test_selfdestruct2() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(selfdestruct_attacker), 10000 ether);
        vm.startPrank(address(selfdestruct_attacker));
        marketplace.registerSeller();
        selfdestruct_attacker.attack();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = selfdestruct_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 0 ether);
        assertEq(address(marketplace).balance, 10000 ether);

        // simple use case to show that selfdestruct will not affect the functionality smart contract
        vm.startPrank(user1);
        marketplace.registerSeller();
        marketplace.addItem("Item1", "Description1", 1 ether);
        vm.stopPrank();

        Marketplace.Item[] memory items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].name, "Item1");
        assertEq(items[0].description, "Description1");
        assertEq(items[0].price, 1 ether);
        assertEq(items[0].seller, user1);
        assertEq(items[0].isSold, false);

        vm.startPrank(user2);
        vm.expectRevert("Only item owner can edit this item");
        marketplace.editItem(1, "NewItem1", "NewDescription1", 2 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        assertEq(marketplace.editItem(1, "NewItem1", "NewDescription1", 2 ether), true);
        vm.stopPrank();

        items = marketplace.viewAllItems();
        assertEq(items.length, 1);
        assertEq(items[0].name, "NewItem1");
        assertEq(items[0].description, "NewDescription1");
        assertEq(items[0].price, 2 ether);
        assertEq(items[0].seller, user1);
        assertEq(items[0].isSold, false);
    }

    function test_selfdestruct3() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(selfdestruct_attacker), 5 ether);
        vm.startPrank(address(selfdestruct_attacker));
        marketplace.registerSeller();
        selfdestruct_attacker.attack();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = selfdestruct_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 0 ether);
        assertEq(address(marketplace).balance, 5 ether);

        // simple use case to show that selfdestruct will not affect the functionality smart contract
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        marketplace.registerBuyer();
        assertEq(marketplace.viewBalance(), 0 ether);
        marketplace.addBalance{value: 0.5 ether}();
        assertEq(marketplace.viewBalance(), 0.5 ether);
        marketplace.withdraw(0.5 ether);
        assertEq(marketplace.viewBalance(), 0 ether);
        assertEq(user1.balance, 1 ether);
        vm.stopPrank();
    }

    function test_selfdestruct4() public {
        uint256 attackerBalanceInMarketplace;
        uint256 attackerBalance;

        vm.deal(address(selfdestruct_attacker), 25 ether);
        vm.startPrank(address(selfdestruct_attacker));
        marketplace.registerSeller();
        selfdestruct_attacker.attack();
        attackerBalanceInMarketplace = marketplace.viewBalance();
        attackerBalance = selfdestruct_attacker.getBalance();
        vm.stopPrank();

        assertEq(attackerBalanceInMarketplace, 0 ether);
        assertEq(attackerBalance, 0 ether);
        assertEq(address(marketplace).balance, 25 ether);

        // simple use case to show that selfdestruct will not affect the functionality smart contract
        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(marketplace.registerBuyer(), true);
        vm.stopPrank();

        vm.startPrank(user3);
        assertEq(marketplace.registerSeller(), true);
        vm.stopPrank();

        vm.startPrank(user1);

        marketplace.addItem("Item1", "Description1", 1);
        marketplace.addItem("Item9", "Hello", 4);
        marketplace.addItem("Item2", "Description2", 2);
        marketplace.addItem("Item9", "Hello2", 20);
        marketplace.addItem("Item10", "Hello4", 20);

        vm.stopPrank();

        vm.startPrank(user3);

        marketplace.addItem("Item9", "Description4", 10);
        marketplace.addItem("Item4", "Description5", 3);
        marketplace.addItem("Item4", "Description4", 4);

        vm.stopPrank();

        // testing for the seller
        vm.startPrank(user1);

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("", "", address(0), 1, 3, 0);
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].price, 1);
        assertEq(filteredItems[1].price, 2);
        assertEq(filteredItems[2].price, 3);

        vm.stopPrank();
    }

    // * Denial-of-service testing *
    // test_dos1 and test_dos2 test the gas limits of the item filtering functionality
    // before, these tests would fail due to the high gas cost of filtering
    // and attackers could destroy the filtering functionality by adding many listings, causing the filtering function to iterate over a vast number of items and crash
    // we implemented pagination in filtering to limit the number of items searched, making gas costs relatively constant for filtering

    function test_dos1() public {
        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        
        for (int i = 0; i < 1000000; i++){
            assertEq(marketplace.addItem("Item1", "Description1", 1 ether), true);
        }

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("", "", address(0), 1 ether, 1 ether, 0);

        assertEq(filteredItems.length, 50);

        vm.stopPrank();
    }

    // more filtering parameters
    function test_dos2() public {
        vm.startPrank(user1);
        assertEq(marketplace.registerSeller(), true);
        
        for (int i = 0; i < 1000000; i++){
            assertEq(marketplace.addItem("Item2", "Description2", 2 ether), true);
        }

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSale("Item2", "Description2", address(user1), 1 ether, 3 ether, 500);

        assertEq(filteredItems.length, 50);

        vm.stopPrank();
    }
}
