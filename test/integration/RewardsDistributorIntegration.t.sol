// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RewardsDistributor} from "../../src/RewardsDistributor.sol";

contract RewardsDistributorUnitTest is Test {
    RewardsDistributor rewardsDistributor;
    address owner;
    address tokenAddress;
    string name;

    function setUp() public {
        string memory rpcUrl = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpcUrl);

        owner = address(this);
        tokenAddress = address(this);
        name = "Test Rewards Distributor";
        rewardsDistributor = new RewardsDistributor(owner, tokenAddress, name);
    }

    function test_InitialValues() public {
        // Rewards Distributor
        assertEq(rewardsDistributor.token(), tokenAddress, "Token address is not set correctly");
        assertEq(rewardsDistributor.name(), name, "Name is not set correctly");
        assertFalse(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should initially be false");

        // Mock ERC20 token
        assertEq(mockToken.name(), "MockToken", "Mock token name is not set correctly");
        assertEq(mockToken.symbol(), "MTK", "Mock token symbol is not set correctly");
    }

    function test_SetShouldFailPayout() public {
        rewardsDistributor.setShouldFailPayout(true);
        assertTrue(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be true after setting");

        rewardsDistributor.setShouldFailPayout(false);
        assertFalse(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be false after setting");
    }
}
