// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";

contract MintableToken is MockERC20 {
    constructor(string memory _symbol, uint8 _decimals) {
        initialize(string.concat("Mintable token ", _symbol), _symbol, _decimals);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract CoreProxyMock {}

contract RewardsDistributorPrecisionTest is Test {
    address private BOB;

    MintableToken internal sUSDC;
    CoreProxyMock internal rewardsManager;

    uint128 internal accountId = 1;
    uint128 internal poolId = 1;
    address internal collateralType;

    function setUp() public {
        BOB = vm.addr(0xB0B);
        rewardsManager = new CoreProxyMock();
        sUSDC = new MintableToken("sUSDC", 18);
        collateralType = address(sUSDC);
    }

    function test_payout_lowerDecimalsToken() public {
        MintableToken T6D = new MintableToken("T6D", 6);
        RewardsDistributor rd = new RewardsDistributor(
            address(rewardsManager),
            poolId,
            collateralType,
            address(T6D),
            "6 Decimals token payouts"
        );
        T6D.mint(address(rd), 1_000e6); // 1000 T6D tokens
        vm.deal(address(rewardsManager), 1 ether);

        assertEq(T6D.balanceOf(address(rd)), 1_000e6);
        assertEq(T6D.balanceOf(BOB), 0);

        vm.startPrank(address(rewardsManager));
        assertTrue(rd.payout(accountId, poolId, collateralType, BOB, 10e18)); // Distribute 10 tokens, the number is in 18 dec precision
        vm.stopPrank();

        assertEq(T6D.balanceOf(address(rd)), 990e6);
        assertEq(T6D.balanceOf(BOB), 10e6);
    }

    function test_payout_higherDecimalsToken() public {
        MintableToken T33D = new MintableToken("T33D", 33);
        RewardsDistributor rd = new RewardsDistributor(
            address(rewardsManager),
            poolId,
            collateralType,
            address(T33D),
            "33 Decimals token payouts"
        );
        T33D.mint(address(rd), 1_000e33); // 1000 T33D tokens
        vm.deal(address(rewardsManager), 1 ether);

        assertEq(T33D.balanceOf(address(rd)), 1_000e33);
        assertEq(T33D.balanceOf(BOB), 0);

        vm.startPrank(address(rewardsManager));
        assertTrue(rd.payout(accountId, poolId, collateralType, BOB, 10e18)); // Distribute 10 tokens, the number is in 18 dec precision
        vm.stopPrank();

        assertEq(T33D.balanceOf(address(rd)), 990e33);
        assertEq(T33D.balanceOf(BOB), 10e33);
    }
}
