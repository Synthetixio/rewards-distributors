// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "cannon-std/Cannon.sol";

import "../src/SnapshotRewardsDistributor.sol";
import {ISynthetixCore} from "../src/interfaces/ISynthetixCore.sol";
import "../src/interfaces/IMintableToken.sol";
import "../src/interfaces/IERC721Receiver.sol";

contract SynthetixSafeModuleTest is Test, IERC721Receiver {
    using Cannon for Vm;

    ISynthetixCore system;
		SnapshotRewardsDistributor rewardsDistributor;
		address collateralAddress;

		uint128 constant accountId = 1234;
		uint256 depositAmount = 1000 * 1e18;

    function setUp() public {
				system = ISynthetixCore(vm.getAddress("ssr.synthetix.CoreProxy"));
        rewardsDistributor = SnapshotRewardsDistributor(vm.getAddress("ssr.RewardsDistributor"));
				collateralAddress = vm.getAddress("token.MintableToken");
    }

    function testInitialState() public view {
        assert(rewardsDistributor.currentPeriodId() == 0);
				assert(rewardsDistributor.servicePoolId() == 1);
				assert(rewardsDistributor.serviceCollateralType() == collateralAddress);
    }

		function testRecordsWhenUserStakes() public {
				system.createAccount(accountId);

				IERC20(collateralAddress).approve(address(system), type(uint).max);

				system.deposit(accountId, collateralAddress, depositAmount);
				system.delegateCollateral(accountId, 1, collateralAddress, depositAmount, 1e18);

				assert(rewardsDistributor.totalSupply() == depositAmount);
				assert(rewardsDistributor.balanceOf(accountId) == depositAmount);
				assert(rewardsDistributor.balanceOf(address(this)) == depositAmount);

				rewardsDistributor.takeSnapshot(1);
				system.delegateCollateral(accountId, 1, collateralAddress, depositAmount / 2, 1e18);

				assert(rewardsDistributor.totalSupply() == depositAmount / 2);
				assert(rewardsDistributor.balanceOf(accountId) == depositAmount / 2);
				assert(rewardsDistributor.balanceOf(address(this)) == depositAmount / 2);

				assert(rewardsDistributor.balanceOfOnPeriod(address(this), 0) == depositAmount);

				rewardsDistributor.takeSnapshot(10);

				system.delegateCollateral(accountId, 1, collateralAddress, 0, 1e18);

		}

		function testFailSnapshot() public {
				rewardsDistributor.takeSnapshot(10);
				// next snapshot is lower than previous
				rewardsDistributor.takeSnapshot(2);
		}

		function testTransferAccount() public {
				
		}

		function testRemoveUserStake() public {
		}

		
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
				) external pure returns (bytes4) {
				return this.onERC721Received.selector;
		}
}
