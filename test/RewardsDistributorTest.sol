// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";
import {IRewardsManagerModule} from "@synthetixio/main/contracts/interfaces/IRewardsManagerModule.sol";
import {IRewardDistributor} from "@synthetixio/main/contracts/interfaces/external/IRewardDistributor.sol";
import {AccessError} from "@synthetixio/core-contracts/contracts/errors/AccessError.sol";
import {ParameterError} from "@synthetixio/core-contracts/contracts/errors/ParameterError.sol";
import {ERC20Helper} from "@synthetixio/core-contracts/contracts/token/ERC20Helper.sol";

import {MintableToken} from "./MintableToken.sol";

contract CoreProxyMock {
    uint128 public poolId;
    address public collateralType;
    uint256 public amount;
    uint64 public start;
    uint32 public duration;
    function distributeRewards(
        uint128 poolId_,
        address collateralType_,
        uint256 amount_,
        uint64 start_,
        uint32 duration_
    ) public {
        poolId = poolId_;
        collateralType = collateralType_;
        amount = amount_;
        start = start_;
        duration = duration_;
    }

    address public poolOwner;
    function getPoolOwner(
        uint128 // poolId_
    ) public view returns (address) {
        return poolOwner;
    }

    constructor(address poolOwner_) {
        poolOwner = poolOwner_;
    }
}

contract RewardsDistributorTest is Test {
    address private ALICE;
    address private BOB;
    address private BOSS;

    MintableToken internal sUSDC;
    MintableToken internal SNX;
    RewardsDistributor internal rewardsDistributor;
    CoreProxyMock internal rewardsManager;

    function setUp() public {
        ALICE = vm.addr(0xA11CE);
        BOB = vm.addr(0xB0B);
        BOSS = vm.addr(0xB055);

        SNX = new MintableToken("SNX", 18);
        sUSDC = new MintableToken("sUSDC", 18);

        rewardsManager = new CoreProxyMock(BOSS);

        uint128 poolId = 1;
        address collateralType = address(sUSDC);
        address payoutToken = address(SNX);
        string memory name = "whatever";

        rewardsDistributor = new RewardsDistributor(
            address(rewardsManager),
            poolId,
            collateralType,
            payoutToken,
            name
        );
    }

    function test_constructor_arguments() public {
        assertEq(rewardsDistributor.rewardManager(), address(rewardsManager));
        assertEq(rewardsDistributor.name(), "whatever");
        assertEq(rewardsDistributor.collateralType(), address(sUSDC));
        assertEq(rewardsDistributor.payoutToken(), address(SNX));
        assertEq(rewardsDistributor.token(), address(SNX));
    }

    function test_setShouldFailPayout_AccessError() public {
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, ALICE));
        rewardsDistributor.setShouldFailPayout(true);
        vm.stopPrank();
    }

    function test_setShouldFailPayout() public {
        vm.startPrank(BOSS);
        assertEq(rewardsDistributor.shouldFailPayout(), false);
        rewardsDistributor.setShouldFailPayout(true);
        assertEq(rewardsDistributor.shouldFailPayout(), true);
        rewardsDistributor.setShouldFailPayout(false);
        assertEq(rewardsDistributor.shouldFailPayout(), false);
        vm.stopPrank();
    }

    function test_payout_AccessError() public {
        uint128 accountId = 1;
        uint128 poolId = 1;
        address collateralType = address(sUSDC);

        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, ALICE));
        assertEq(rewardsDistributor.payout(accountId, poolId, collateralType, BOB, 100), false);
        vm.stopPrank();
    }

    function test_payout_WrongPool() public {
        SNX.mint(address(rewardsDistributor), 1000e18);
        vm.startPrank(address(rewardsManager));

        uint128 accountId = 1;
        uint128 poolId = 2;
        address collateralType = address(sUSDC);
        vm.expectRevert(
            abi.encodeWithSelector(
                ParameterError.InvalidParameter.selector,
                "poolId",
                "Pool does not match the rewards pool"
            )
        );
        assertEq(rewardsDistributor.payout(accountId, poolId, collateralType, BOB, 10e18), false);
        vm.stopPrank();
    }

    function test_payout_WrongCollateralType() public {
        SNX.mint(address(rewardsDistributor), 1000e18);
        vm.startPrank(address(rewardsManager));

        uint128 accountId = 1;
        uint128 poolId = 1;
        address collateralType = address(0); // wrong one
        vm.expectRevert(
            abi.encodeWithSelector(
                ParameterError.InvalidParameter.selector,
                "collateralType",
                "Collateral does not match the rewards token"
            )
        );
        assertEq(rewardsDistributor.payout(accountId, poolId, collateralType, BOB, 10e18), false);
        vm.stopPrank();
    }

    function test_payout_underflow() public {
        vm.startPrank(address(rewardsManager));

        uint128 accountId = 1;
        uint128 poolId = 1;
        address collateralType = address(sUSDC);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Helper.FailedTransfer.selector,
                address(rewardsDistributor),
                BOB,
                10e18
            )
        );
        assertEq(rewardsDistributor.payout(accountId, poolId, collateralType, BOB, 10e18), false);
        vm.stopPrank();
    }

    function test_payout_shouldFail() public {
        SNX.mint(address(rewardsDistributor), 1000e18);

        uint128 accountId = 1;
        uint128 poolId = 1;
        address collateralType = address(sUSDC);

        vm.startPrank(BOSS);
        rewardsDistributor.setShouldFailPayout(true);
        vm.stopPrank();

        vm.startPrank(address(rewardsManager));
        assertEq(rewardsDistributor.payout(accountId, poolId, collateralType, BOB, 10e18), false);
        vm.stopPrank();
    }

    function test_payout() public {
        SNX.mint(address(rewardsDistributor), 1000e18);

        uint128 accountId = 1;
        uint128 poolId = 1;
        address collateralType = address(sUSDC);

        vm.startPrank(address(rewardsManager));
        assertTrue(rewardsDistributor.payout(accountId, poolId, collateralType, BOB, 10e18));
        vm.stopPrank();
    }

    function test_distributeRewards_AccessError() public {
        uint128 poolId = 1;
        address collateralType = address(sUSDC);
        uint256 amount = 100e18;
        uint64 start = 12345678;
        uint32 duration = 3600;

        vm.startPrank(ALICE);

        vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, ALICE));
        rewardsDistributor.distributeRewards(poolId, collateralType, amount, start, duration);
        vm.stopPrank();
    }

    function test_distributeRewards_WrongPool() public {
        uint128 poolId = 2;
        address collateralType = address(sUSDC);
        uint256 amount = 100e18;
        uint64 start = 12345678;
        uint32 duration = 3600;

        vm.startPrank(BOSS);

        vm.expectRevert(
            abi.encodeWithSelector(
                ParameterError.InvalidParameter.selector,
                "poolId",
                "Pool does not match the rewards pool"
            )
        );
        rewardsDistributor.distributeRewards(poolId, collateralType, amount, start, duration);
        vm.stopPrank();
    }

    function test_distributeRewards_WrongCollateralType() public {
        uint128 poolId = 1;
        address collateralType = address(SNX); // incorrect one
        uint256 amount = 100e18;
        uint64 start = 12345678;
        uint32 duration = 3600;

        vm.startPrank(BOSS);

        vm.expectRevert(
            abi.encodeWithSelector(
                ParameterError.InvalidParameter.selector,
                "collateralType",
                "Collateral does not match the rewards token"
            )
        );
        rewardsDistributor.distributeRewards(poolId, collateralType, amount, start, duration);
        vm.stopPrank();
    }

    function test_distributeRewards() public {
        uint128 poolId = 1;
        address collateralType = address(sUSDC);
        uint256 amount = 100e18;
        uint64 start = 12345678;
        uint32 duration = 3600;

        vm.startPrank(BOSS);
        rewardsDistributor.distributeRewards(poolId, collateralType, amount, start, duration);
        vm.stopPrank();
        assertEq(rewardsManager.poolId(), poolId);
        assertEq(rewardsManager.collateralType(), collateralType);
        assertEq(rewardsManager.amount(), 100e18);
        assertEq(rewardsManager.start(), 12345678);
        assertEq(rewardsManager.duration(), 3600);
    }

    function test_onPositionUpdated() public {
        SNX.mint(address(rewardsDistributor), 1000e18);
        uint128 accountId = 1;
        uint128 poolId = 1;
        address collateralType = address(sUSDC);
        uint256 actorSharesD18 = 123;
        rewardsDistributor.onPositionUpdated(accountId, poolId, collateralType, actorSharesD18);
    }

    function test_supportsInterface() public {
        assertEq(rewardsDistributor.supportsInterface(type(IRewardDistributor).interfaceId), true);
        bytes4 anotherInterface = bytes4(keccak256(bytes("123")));
        assertEq(rewardsDistributor.supportsInterface(anotherInterface), false);
    }
}
