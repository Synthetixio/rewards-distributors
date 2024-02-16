// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IRewardDistributor} from "@synthetixio/main/contracts/interfaces/external/IRewardDistributor.sol";
import {AccessError} from "@synthetixio/core-contracts/contracts/errors/AccessError.sol";
import {ParameterError} from "@synthetixio/core-contracts/contracts/errors/ParameterError.sol";
import {ERC20Helper} from "@synthetixio/core-contracts/contracts/token/ERC20Helper.sol";
import {IERC165} from "@synthetixio/core-contracts/contracts/interfaces/IERC165.sol";
import {IERC20} from "@synthetixio/core-contracts/contracts/interfaces/IERC20.sol";
import {ISynthetixCore} from "./interfaces/ISynthetixCore.sol";

contract RewardsDistributor is IRewardDistributor {
    using ERC20Helper for address;

    address public rewardManager;
    uint128 public poolId;
    address public collateralType;
    address public payoutToken;
    string public name;

    bool public shouldFailPayout;

    constructor(
        address rewardManager_,
        uint128 poolId_,
        address collateralType_,
        address payoutToken_,
        string memory name_
    ) {
        rewardManager = rewardManager_; // Synthetix CoreProxy
        poolId = poolId_;
        collateralType = collateralType_;
        payoutToken = payoutToken_;
        name = name_;
    }

    function token() public view returns (address) {
        return payoutToken;
    }

    function setShouldFailPayout(bool shouldFailPayout_) external {
        if (msg.sender != ISynthetixCore(rewardManager).getPoolOwner(poolId)) {
            revert AccessError.Unauthorized(msg.sender);
        }
        shouldFailPayout = shouldFailPayout_;
    }

    function payout(
        uint128, // accountId,
        uint128 poolId_,
        address collateralType_,
        address payoutTarget_, // msg.sender of claimRewards() call, payout target address
        uint256 payoutAmount_
    ) external returns (bool) {
        if (shouldFailPayout) {
            return false;
        }
        // IMPORTANT: In production, this function should revert if msg.sender is not the Synthetix CoreProxy address.
        if (msg.sender != rewardManager) {
            revert AccessError.Unauthorized(msg.sender);
        }
        if (poolId_ != poolId) {
            revert ParameterError.InvalidParameter(
                "poolId",
                "Pool does not match the rewards pool"
            );
        }
        if (collateralType_ != collateralType) {
            revert ParameterError.InvalidParameter(
                "collateralType",
                "Collateral does not match the rewards token"
            );
        }

        // payoutAmount_ is always in 18 decimals precision, adjust actual payout amount to match payout token decimals
        uint256 systemPrecision = 10 ** 18;
        uint256 distributorPrecision = 10 ** IERC20(payoutToken).decimals();
        uint256 adjustedAmount = (payoutAmount_ / systemPrecision) * distributorPrecision;
        payoutToken.safeTransfer(payoutTarget_, adjustedAmount);
        return true;
    }

    function distributeRewards(
        uint128 poolId_,
        address collateralType_,
        uint256 amount_,
        uint64 start_,
        uint32 duration_
    ) public {
        if (msg.sender != ISynthetixCore(rewardManager).getPoolOwner(poolId)) {
            revert AccessError.Unauthorized(msg.sender);
        }
        if (poolId_ != poolId) {
            revert ParameterError.InvalidParameter(
                "poolId",
                "Pool does not match the rewards pool"
            );
        }
        if (collateralType_ != collateralType) {
            revert ParameterError.InvalidParameter(
                "collateralType",
                "Collateral does not match the rewards token"
            );
        }

        // amount_ is in payout token decimals precision, adjust actual distribution amount to 18 decimals that core is making its calculations in
        // this is necessary to avoid rounding issues when doing actual payouts
        uint256 systemPrecision = 10 ** 18;
        uint256 distributorPrecision = 10 ** IERC20(payoutToken).decimals();
        uint256 adjustedAmount = (amount_ / distributorPrecision) * systemPrecision;

        ISynthetixCore(rewardManager).distributeRewards(
            poolId_,
            collateralType_,
            adjustedAmount,
            start_,
            duration_
        );
    }

    function onPositionUpdated(
        uint128, // accountId,
        uint128, // poolId,
        address, // collateralType,
        uint256 // actorSharesD18
    ) external {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == type(IRewardDistributor).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }
}
