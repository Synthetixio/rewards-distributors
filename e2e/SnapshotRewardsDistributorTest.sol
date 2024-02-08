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

    ISynthetixCore private system;
    IERC721 private accountToken;
    SnapshotRewardsDistributor private rewardsDistributor;
    address private collateralAddress;

    uint128 private constant accountId = 1234;
    uint256 private constant depositAmount = 1000 * 1e18;

    function setUp() public {
        system = ISynthetixCore(vm.getAddress("ssr.synthetix.CoreProxy"));
        accountToken = IERC721(vm.getAddress("ssr.synthetix.AccountProxy"));
        rewardsDistributor = SnapshotRewardsDistributor(vm.getAddress("ssr.RewardsDistributor"));
        collateralAddress = vm.getAddress("token.MintableToken");
    }

    function testInitialState() public view {
        assert(rewardsDistributor.currentPeriodId() == 0);
        assert(rewardsDistributor.servicePoolId() == 1);
        assert(rewardsDistributor.serviceCollateralType() == collateralAddress);

        assert(rewardsDistributor.balanceOf(accountId) == 0);
        assert(rewardsDistributor.balanceOf(address(this)) == 0);
    }

    function testRecordsWhenUserStakes() public {
        system.createAccount(accountId);

        IERC20(collateralAddress).approve(address(system), type(uint256).max);

        system.deposit(accountId, collateralAddress, depositAmount);
        system.delegateCollateral(accountId, 1, collateralAddress, depositAmount, 1e18);

        assert(rewardsDistributor.totalSupply() == depositAmount);
        assert(rewardsDistributor.balanceOf(accountId) == depositAmount);
        assert(rewardsDistributor.balanceOf(address(this)) == depositAmount);

        rewardsDistributor.takeSnapshot(1);
        system.delegateCollateral(accountId, 1, collateralAddress, depositAmount / 3, 1e18);
        system.delegateCollateral(accountId, 1, collateralAddress, depositAmount / 2, 1e18);

        assert(rewardsDistributor.totalSupply() == depositAmount / 2);
        assert(rewardsDistributor.balanceOf(accountId) == depositAmount / 2);
        assert(rewardsDistributor.balanceOf(address(this)) == depositAmount / 2);

        assert(rewardsDistributor.balanceOfOnPeriod(address(this), 0) == depositAmount);

        rewardsDistributor.takeSnapshot(10);
        rewardsDistributor.takeSnapshot(20);

        system.delegateCollateral(accountId, 1, collateralAddress, 0, 1e18);
    }

    function testWhenRecordHistoryExceeded() public {
        system.createAccount(accountId);

        IERC20(collateralAddress).approve(address(system), type(uint256).max);

        system.deposit(accountId, collateralAddress, depositAmount);
        system.delegateCollateral(accountId, 1, collateralAddress, depositAmount, 1e18);

        for (uint128 i = 0; i < 100; i++) {
            rewardsDistributor.takeSnapshot(i * 10 + 1);
            system.delegateCollateral(
                accountId,
                1,
                collateralAddress,
                depositAmount / (i + 2),
                1e18
            );
        }

        assert(rewardsDistributor.balanceOfOnPeriod(accountId, 981) == depositAmount / 100);
        assert(rewardsDistributor.balanceOfOnPeriod(accountId, 980) == depositAmount / 99);
        assert(rewardsDistributor.balanceOfOnPeriod(address(this), 982) == depositAmount / 100);
        assert(rewardsDistributor.balanceOfOnPeriod(address(this), 981) == depositAmount / 100);
        assert(rewardsDistributor.balanceOfOnPeriod(address(this), 980) == depositAmount / 99);

        vm.expectRevert("SynthetixDebtShare: not found in recent history");
        rewardsDistributor.balanceOfOnPeriod(accountId, 11);

        vm.expectRevert("SynthetixDebtShare: not found in recent history");
        rewardsDistributor.balanceOfOnPeriod(address(this), 11);
    }

    function testSnapshotFailures() public {
        vm.expectRevert("unauthorized");
        vm.prank(address(0x1));
        rewardsDistributor.takeSnapshot(1234);

        rewardsDistributor.takeSnapshot(10);
        // next snapshot is lower than previous
        vm.expectRevert("period id must always increase");
        rewardsDistributor.takeSnapshot(2);
    }

    function testOnPositionUpdatedFailures() public {
        vm.expectRevert("unauthorized");
        rewardsDistributor.onPositionUpdated(0, 0, address(0), 0);

        vm.expectRevert(
            abi.encodePacked(
                SnapshotRewardsDistributor.IncorrectPoolId.selector,
                uint256(1234),
                uint256(1)
            )
        );
        vm.prank(address(system));
        rewardsDistributor.onPositionUpdated(1234, 1234, address(0), 0);

        vm.expectRevert(
            abi.encodePacked(
                SnapshotRewardsDistributor.IncorrectCollateralType.selector,
                uint256(uint160(address(0))),
                uint256(uint160(address(collateralAddress)))
            )
        );
        vm.prank(address(system));
        rewardsDistributor.onPositionUpdated(1, 1, address(0), 0);
    }

    function testTransferAccount() public {
        system.createAccount(accountId);

        IERC20(collateralAddress).approve(address(system), type(uint256).max);

        system.deposit(accountId, collateralAddress, depositAmount);
        system.delegateCollateral(accountId, 1, collateralAddress, depositAmount, 1e18);

        assert(rewardsDistributor.totalSupply() == depositAmount);
        assert(rewardsDistributor.balanceOf(accountId) == depositAmount);
        assert(rewardsDistributor.balanceOf(address(this)) == depositAmount);

        accountToken.transferFrom(address(this), address(0x1), accountId);

        assert(rewardsDistributor.balanceOf(address(this)) == depositAmount);

        vm.prank(address(0x1));
        system.delegateCollateral(accountId, 1, collateralAddress, depositAmount / 2, 1e18);

        assert(rewardsDistributor.totalSupply() == depositAmount / 2);
        assert(rewardsDistributor.balanceOf(address(this)) == 0);
        assert(rewardsDistributor.balanceOf(address(0x1)) == depositAmount / 2);
    }

    function testPayout() public {
        assert(rewardsDistributor.payout(0, 0, address(0), address(0), 0));
    }

    function testName() public {
        // does not revert?
        rewardsDistributor.name();
    }

    function testToken() public {
        assert(rewardsDistributor.token() == address(0));
    }

    function testInterfaceSupported() public {
        assert(rewardsDistributor.supportsInterface(type(IRewardDistributor).interfaceId));
        assert(
            rewardsDistributor.supportsInterface(
                SnapshotRewardsDistributor.supportsInterface.selector
            )
        );

        assert(!rewardsDistributor.supportsInterface(0x000000000));
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
