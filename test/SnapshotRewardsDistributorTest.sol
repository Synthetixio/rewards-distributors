// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "cannon-std/Cannon.sol";

import "../src/SnapshotRewardsDistributor.sol";
import {ISynthetixCore} from "../src/interfaces/ISynthetixCore.sol";

contract SynthetixSafeModuleTest is Test {
    using Cannon for Vm;

    ISynthetixCore system;
		SnapshotRewardsDistributor rewardsDistributor;

    function setUp() public {
				system = ISynthetixCore(vm.getAddress("synthetix.CoreProxy"));
        rewardsDistributor = SnapshotRewardsDistributor(vm.getAddress("RewardsDistributor"));
    }

    function testInitialState() public view {
        assert(rewardsDistributor.currentPeriodId() == 0);
    }
}
