// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";
import "./mocks/MockERC20.sol";

contract RewardsDistributorUnitTest is Test {
    RewardsDistributor rewardsDistributor;
    MockERC20 mockToken;

    address manager;
    address tokenAddress;
    string name;

    function setUp() public {
        manager = address(this);
        tokenAddress = address(this);
        name = "Test Rewards Distributor";
        rewardsDistributor = new RewardsDistributor(manager, tokenAddress, name);
    }

    function test_InitialValues() public {
        assertEq(rewardsDistributor.token(), tokenAddress, "Token address is not set correctly");
        assertEq(rewardsDistributor.name(), name, "Name is not set correctly");
        assertFalse(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should initially be false");
    }

    function test_SetShouldFailPayout() public {
        rewardsDistributor.setShouldFailPayout(true);
        assertTrue(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be true after setting");
        rewardsDistributor.setShouldFailPayout(false);
        assertFalse(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be false after setting");
    }
}
