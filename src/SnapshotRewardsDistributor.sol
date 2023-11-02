// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IRewardsManagerModule} from "@synthetixio/main/contracts/interfaces/IRewardsManagerModule.sol"; 
import {IAccountModule} from "@synthetixio/main/contracts/interfaces/IAccountModule.sol"; 
import {IERC721} from "@synthetixio/core-contracts/contracts/interfaces/IERC721.sol";
import {IRewardDistributor} from "@synthetixio/main/contracts/interfaces/external/IRewardDistributor.sol";
import "./interfaces/ISnapshotRecord.sol";
import {AccessError} from "@synthetixio/core-contracts/contracts/errors/AccessError.sol";
import {IERC20} from "@synthetixio/core-contracts/contracts/interfaces/IERC20.sol";
import {IERC165} from "@synthetixio/core-contracts/contracts/interfaces/IERC165.sol";

contract SnapshotRewardsDistributor is IRewardDistributor, ISnapshotRecord {
		IRewardsManagerModule rewardsManager;
		IERC721 accountToken;
		uint256 servicePoolId;
		address serviceCollateralType;


		
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

		uint128 currentPeriodId;
		
    uint internal constant MAX_PERIOD_ITERATE = 30;

    constructor(IRewardsManagerModule _rewardsManager, uint128 _servicePoolId, address _serviceCollateralType, address snapper) {
				servicePoolId = _servicePoolId;
				serviceCollateralType = _serviceCollateralType;
        rewardsManager = _rewardsManager;
				accountToken = IERC721(IAccountModule(address(rewardsManager)).getAccountTokenAddress());
				authorizedToSnapshot[snapper] = true;
    }

    function onPositionUpdated(uint128 poolId, uint128 accountId, address collateralType, uint256 newAmount) external {
				if (msg.sender != address(rewardsManager)) {
					revert("unauthorized");
				}

				if (poolId != servicePoolId || collateralType != serviceCollateralType) {
					revert("incorrect pool id");
				}

				address account = accountToken.ownerOf(accountId);

        uint ownerAccountRecordsCount = ownerToAccountId[account].length;

        if (ownerAccountRecordsCount == 0 || ownerToAccountId[account][ownerAccountRecordsCount - 1].periodId != currentPeriodId) {
            ownerToAccountId[account].push();
						ownerToAccountId[account][ownerAccountRecordsCount].periodId = currentPeriodId;
				}

				bool found = false;
				for (uint i = 0;i < ownerToAccountId[account][ownerAccountRecordsCount - 1].accountIds.length;i++) {
						found = found || ownerToAccountId[account][ownerAccountRecordsCount - 1].accountIds[i] == accountId;
				}

				if (!found) {
						ownerToAccountId[account][ownerAccountRecordsCount - 1].accountIds.push(accountId);
				}

        uint accountBalanceCount = balances[accountId].length;

        if (accountBalanceCount == 0) {
            balances[accountId].push(PeriodBalance(uint128(newAmount), uint128(currentPeriodId)));
        } else {
            if (balances[accountId][accountBalanceCount - 1].periodId != currentPeriodId) {
                balances[accountId].push(PeriodBalance(uint128(newAmount), currentPeriodId));
            } else {
                balances[accountId][accountBalanceCount - 1].amount = uint128(newAmount);
            }
        }
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
