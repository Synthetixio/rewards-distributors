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
    string name = "Test Rewards Distributor";

    // Mainnet SNX and Spartan Pool
    address collateralType = address(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F);
    uint128 poolId = 1;

    MockERC20 mockToken;

    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function setUp() public {
        string memory rpcUrl = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpcUrl);
        mockToken = new MockERC20("MockToken", "MTK", 100_000);
        tokenAddress = address(mockToken);
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

    function test_DistributionSuccess() public {
        uint256 initialBalance = mockToken.balanceOf(address(rewardsDistributor));
        assertEq(initialBalance, 50_000, "Rewards distributor balance is not set correctly");
        
        vm.prank(msgSender);
        // uint256 payoutAmount = 100;
        // address recipient = address(this);

        // Ensure the payout succeeds and recipient receives the amount
        // rewardsDistributor.distributeRewards(poolId, collateralType, payoutAmount, getCurrentTimestamp(), 0);
        // bool success = rewardsDistributor.payout(0, 0, address(0), recipient, payoutAmount);


        // uint256 recipientBalance = rewardsDistributor.token().balanceOf(recipient);
        // Assert.equal(recipientBalance, payoutAmount, "Recipient balance should be equal to the payout amount");

        // uint256 updatedBalance = rewardsDistributor.token().balanceOf(address(rewardsDistributor));
        // Assert.equal(updatedBalance, initialBalance - payoutAmount, "RewardsDistributor balance should decrease");
    }

    function test_PayoutFail() public {
        rewardsDistributor.setShouldFailPayout(true);
        assertTrue(rewardsDistributor.shouldFailPayout(), "shouldFailPayout should be true after setting");
    }
}
