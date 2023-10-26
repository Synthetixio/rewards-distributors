// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {RewardsDistributor} from "../../src/RewardsDistributor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract RewardsDistributorUnitTest is Test {
    RewardsDistributor rewardsDistributor;

    // Mainnet CoreProxy
    address manager = address(0xffffffaEff0B96Ea8e4f94b2253f31abdD875847);
    address tokenAddress;
    string name;

    MockERC20 mockToken;

    function setUp() public {
        string memory rpcUrl = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpcUrl);


        // Initialize mock ERC20 token
        mockToken = new MockERC20("MockToken", "MTK", 100_000);
        console.log("Mock token address: %s", address(mockToken));

        tokenAddress = address(mockToken);
        name = "Test Rewards Distributor";
        rewardsDistributor = new RewardsDistributor(manager, tokenAddress, name);

        mockToken.transfer(address(rewardsDistributor), 50_000);
    }

    function test_InitialValues() public {
        // Mock ERC20 token
        assertEq(mockToken.name(), "MockToken", "Mock token name is not set correctly");
        assertEq(mockToken.symbol(), "MTK", "Mock token symbol is not set correctly");

        // Check distributor balance
        assertEq(mockToken.balanceOf(address(rewardsDistributor)), 50_000, "Rewards distributor balance is not set correctly");
    }

    function test_SetShouldFailPayout() public {
        rewardsDistributor.setShouldFailPayout(true);
        assertTrue(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be true after setting");

        rewardsDistributor.setShouldFailPayout(false);
        assertFalse(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be false after setting");
    }
}
