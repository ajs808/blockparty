// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;

    address public admin = address(0x01);
    address public user1 = address(0x02);
    address public user2 = address(0x03);
    address public user3 = address(0x04);

    // ==Functional testing==

    function setUp() public {
        vm.startPrank(admin);
        marketplace = new Marketplace();
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
        Marketplace.Item[] memory itemsForSale = marketplace.viewItemsForSale();
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
        Marketplace.Item[] memory itemsForSale = marketplace.viewItemsForSale();
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
    function test_filterItemsForSaleByName() public {

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

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSalebyName(items, "Item1");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item1");

        filteredItems = marketplace.filterItemsForSalebyName(items, "Item4");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item4");

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSalebyName(items, "Item1");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item1");

        filteredItems = marketplace.filterItemsForSalebyName(items, "Item4");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].name, "Item4");

        vm.stopPrank();

    }

    // Test filtering by description
    function test_filterItemsForSaleByDescription() public {

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

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSalebyDescription(items, "Description1");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description1");

        filteredItems = marketplace.filterItemsForSalebyDescription(items, "Description4");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description4");

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSalebyDescription(items, "Description1");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description1");

        filteredItems = marketplace.filterItemsForSalebyDescription(items, "Description4");
        assertEq(filteredItems.length, 1);
        assertEq(filteredItems[0].description, "Description4");

        vm.stopPrank();

    }

    // Test filtering by seller
    function test_filterItemsForSaleBySeller() public {

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

        Marketplace.Item[] memory filteredItems = marketplace.filterItemsForSalebySeller(items, address(user1));
        assertEq(filteredItems.length, 2);
        assertEq(filteredItems[0].seller, address(user1));
        assertEq(filteredItems[1].seller, address(user1));

        filteredItems = marketplace.filterItemsForSalebySeller(items, address(user3));
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].seller, address(user3));
        assertEq(filteredItems[1].seller, address(user3));
        assertEq(filteredItems[2].seller, address(user3));

        vm.stopPrank();

        // testing for the buyer
        vm.startPrank(user2);

        filteredItems = marketplace.filterItemsForSalebySeller(items, address(user1));
        assertEq(filteredItems.length, 2);
        assertEq(filteredItems[0].seller, address(user1));
        assertEq(filteredItems[1].seller, address(user1));

        filteredItems = marketplace.filterItemsForSalebySeller(items, address(user3));
        assertEq(filteredItems.length, 3);
        assertEq(filteredItems[0].seller, address(user3));
        assertEq(filteredItems[1].seller, address(user3));
        assertEq(filteredItems[2].seller, address(user3));

        vm.stopPrank();
    }

    

}

