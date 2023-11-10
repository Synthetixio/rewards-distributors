// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IRewardsManagerModule} from "@synthetixio/main/contracts/interfaces/IRewardsManagerModule.sol"; 
import {IERC721} from "@synthetixio/core-contracts/contracts/interfaces/IERC721.sol";
import {IRewardDistributor} from "@synthetixio/main/contracts/interfaces/external/IRewardDistributor.sol";
import "./interfaces/ISnapshotRecord.sol";
import {AccessError} from "@synthetixio/core-contracts/contracts/errors/AccessError.sol";
import {IERC20} from "@synthetixio/core-contracts/contracts/interfaces/IERC20.sol";
import {IERC165} from "@synthetixio/core-contracts/contracts/interfaces/IERC165.sol";

import "./interfaces/ISynthetixCore.sol";

import "forge-std/console.sol";

contract SnapshotRewardsDistributor is IRewardDistributor, ISnapshotRecord {
		ISynthetixCore rewardsManager;
		IERC721 accountToken;
		uint128 public servicePoolId;
		address public serviceCollateralType;

		error IncorrectPoolId(uint128, uint128);
		error IncorrectCollateralType(address, address);

		
    struct PeriodBalance {
        uint128 amount;
        uint128 periodId;
    }

		struct PeriodAccounts {
				uint128 periodId;
				uint128[] accountIds;
		}

    /**
     * Addresses selected by owner which are allowed to call `takeSnapshot`
     * `takeSnapshot` is not public because only a small number of snapshots can be retained for a period of time, and so they
     * must be controlled to prevent censorship
     */
    mapping(address => bool) public authorizedToSnapshot;

    /**
     * Records a user's balance as it changes from period to period.
     * The last item in the array always represents the user's most recent balance
     * The intermediate balance is only recorded if
     * `currentPeriodId` differs (which would happen upon a call to `setCurrentPeriodId`)
     */
    mapping(uint128 => PeriodBalance[]) public balances;

    /**
     * Records totalSupply as it changes from period to period
     * Similar to `balances`, the `totalSupplyOnPeriod` at index `currentPeriodId` matches the current total supply
     * Any other period ID would represent its most recent totalSupply before the period ID changed.
     */
    mapping(uint => uint) public totalSupplyOnPeriod;

		/**
		 * Records the latest address to which account it is part of
		 */
		mapping(address => PeriodAccounts[]) ownerToAccountId;

		uint128 public currentPeriodId;
		
    uint internal constant MAX_PERIOD_ITERATE = 30;

    constructor(ISynthetixCore _rewardsManager, uint128 _servicePoolId, address _serviceCollateralType, address snapper) {
				servicePoolId = _servicePoolId;
				serviceCollateralType = _serviceCollateralType;
        rewardsManager = _rewardsManager;
				accountToken = IERC721(rewardsManager.getAccountTokenAddress());
				authorizedToSnapshot[snapper] = true;
    }

    function onPositionUpdated(uint128 accountId, uint128 poolId, address collateralType, uint256 oldAmount) external {
				if (msg.sender != address(rewardsManager)) {
					revert("unauthorized");
				}

				if (poolId != servicePoolId) {
					revert IncorrectPoolId(poolId, servicePoolId);
				}

				if (collateralType != serviceCollateralType) {
					revert IncorrectCollateralType(collateralType, serviceCollateralType);
				}

				console.log("eight");

				uint256 newAmount = ISynthetixCore(address(rewardsManager)).getPositionCollateral(accountId, poolId, collateralType);

				console.log("nine");

				address account = accountToken.ownerOf(accountId);

        uint ownerAccountRecordsCount = ownerToAccountId[account].length;

				console.log("a");

        if (ownerAccountRecordsCount == 0 || ownerToAccountId[account][ownerAccountRecordsCount - 1].periodId != currentPeriodId) {
            ownerToAccountId[account].push();
						ownerToAccountId[account][ownerAccountRecordsCount].periodId = currentPeriodId;
						ownerAccountRecordsCount++;
				}

				console.log("b");

				bool found = false;
				for (uint i = 0;i < ownerToAccountId[account][ownerAccountRecordsCount - 1].accountIds.length;i++) {
						found = found || ownerToAccountId[account][ownerAccountRecordsCount - 1].accountIds[i] == accountId;
				}

				console.log("c");

				if (!found) {
						ownerToAccountId[account][ownerAccountRecordsCount - 1].accountIds.push(accountId);
				}
				
				console.log("d");

        uint accountBalanceCount = balances[accountId].length;

				uint prevBalance = 0;
        if (accountBalanceCount == 0) {
            balances[accountId].push(PeriodBalance(uint128(newAmount), uint128(currentPeriodId)));
        } else {
						prevBalance = balances[accountId][accountBalanceCount - 1].amount;
            if (balances[accountId][accountBalanceCount - 1].periodId != currentPeriodId) {
                balances[accountId].push(PeriodBalance(uint128(newAmount), currentPeriodId));
            } else {
                balances[accountId][accountBalanceCount - 1].amount = uint128(newAmount);
            }
        }

				console.log("CHANGING TOTAL SUPPLY", totalSupplyOnPeriod[currentPeriodId]);
        totalSupplyOnPeriod[currentPeriodId] = totalSupplyOnPeriod[currentPeriodId] + newAmount - prevBalance;
    }
		
		function balanceOfOnPeriod(address account, uint periodId) public view returns (uint) {
        uint accountPeriodHistoryCount = ownerToAccountId[account].length;

        int oldestHistoryIterate =
            int(MAX_PERIOD_ITERATE < accountPeriodHistoryCount ? accountPeriodHistoryCount - MAX_PERIOD_ITERATE : 0);
        int i;
        for (i = int(accountPeriodHistoryCount) - 1; i >= oldestHistoryIterate; i--) {
            if (ownerToAccountId[account][uint(i)].periodId <= periodId) {
								uint128[] storage accountIds = ownerToAccountId[account][uint(i)].accountIds;
								uint totalBalances;
								for (uint j = 0;j < accountIds.length;j++) {
										totalBalances += balanceOfOnPeriod(accountIds[j], periodId);
								}
                return totalBalances;
            }
        }

        require(i < 0, "SynthetixDebtShare: not found in recent history");
        return 0;
		}

		function balanceOfOnPeriod(uint128 accountId, uint periodId) public view returns (uint) {
        uint accountPeriodHistoryCount = balances[accountId].length;

        int oldestHistoryIterate =
            int(MAX_PERIOD_ITERATE < accountPeriodHistoryCount ? accountPeriodHistoryCount - MAX_PERIOD_ITERATE : 0);
        int i;
        for (i = int(accountPeriodHistoryCount) - 1; i >= oldestHistoryIterate; i--) {
            if (balances[accountId][uint(i)].periodId <= periodId) {
                return uint(balances[accountId][uint(i)].amount);
            }
        }

        require(i < 0, "SynthetixDebtShare: not found in recent history");
        return 0;
    }

		function balanceOf(uint128 accountId) external view returns (uint) {
				return balanceOfOnPeriod(accountId, currentPeriodId);
		}

		function balanceOf(address user) external view returns (uint) {
				return balanceOfOnPeriod(user, currentPeriodId);
		}

		function totalSupply() external view returns (uint) {
				return totalSupplyOnPeriod[currentPeriodId];
		}

    function takeSnapshot(uint128 id) external {
				require(authorizedToSnapshot[msg.sender], "unauthorized");
        require(id > currentPeriodId, "period id must always increase");
        totalSupplyOnPeriod[id] = totalSupplyOnPeriod[currentPeriodId];
        currentPeriodId = id;
		}
		
    function payout(
        uint128,
        uint128,
        address,
        address sender,
        uint256 amount
    ) external returns (bool) {
				// this is not a rewards distributor that pays out any tokens
    }

    function name() public pure override returns (string memory) {
        return "snapshot tracker for governance";
    }

    function token() public pure override returns (address) {
				return address(0);
    }


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
