// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "cannon-std/Cannon.sol";

import "../src/SnapshotRewardsDistributor.sol";

contract SynthetixSafeModuleTest is Test {
    using Cannon for Vm;

    ISynthetixV3 system;
		SnapshotRewardsDistributor rewardsDistributor;

    function setUp() public {
				system = SnapshotRewardsDistributor(vm.getAddress("system.CoreProxy"));
        rewardsDistributor = SnapshotRewardsDistributor(vm.getAddress("RewardsDistributor"));
    }

    function testInitialState() public view {
        assert(rewardsDistributor.currentPeriodId() == 0);
    }
}
