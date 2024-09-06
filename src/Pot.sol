// SPDX-License-Identifier: MIT
// @audit-info It's better to have static solidity version solidity 0.8.20
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Pot is Ownable(msg.sender) {
    error Pot__RewardNotFound();
    error Pot__InsufficientFunds();
    error Pot__StillOpenForClaim();

    // @audit-info what is i_, an array is not an immutable variable
    address[] private i_players;
    uint256[] private i_rewards;
    address[] private claimants;
    uint256 private immutable i_totalRewards;
    uint256 private immutable i_deployedAt;
    IERC20 private immutable i_token;
    mapping(address => uint256) private playersToRewards;
    uint256 private remainingRewards;
    // @audit-info constant should be in uppercase
    uint256 private constant managerCutPercent = 10;

    constructor(
        address[] memory players,
        uint256[] memory rewards,
        IERC20 token,
        uint256 totalRewards
    ) {
        i_players = players;
        i_rewards = rewards;
        i_token = token;
        i_totalRewards = totalRewards;
        remainingRewards = totalRewards;
        i_deployedAt = block.timestamp;

        // i_token.transfer(address(this), i_totalRewards);

        for (uint256 i = 0; i < i_players.length; i++) {
            playersToRewards[i_players[i]] = i_rewards[i];
        }
    }

    // @audit-info natspec ??
    function claimCut() public {
        address player = msg.sender;
        uint256 reward = playersToRewards[player];
        if (reward <= 0) {
            revert Pot__RewardNotFound();
        }
        playersToRewards[player] = 0;
        remainingRewards -= reward;
        claimants.push(player);
        _transferReward(player, reward);
    }

    // @audit-info natspec ??
    function closePot() external onlyOwner {
        // @audit-info Please use constant and not magic number
        if (block.timestamp - i_deployedAt < 90 days) {
            revert Pot__StillOpenForClaim();
        }
        if (remainingRewards > 0) {
            uint256 managerCut = remainingRewards / managerCutPercent;
            i_token.transfer(msg.sender, managerCut);
            // @audit-medium if the player length is 0 then it's broken
            // @audit-high claimingCut is calculated on player and not claimants !
            // Suppose we have remaining reward equals to 100 tokens and 3 players but only 2 claimants.
            // Here we will have 100-10/3 => claimantCut = 30. But we only have 2 claimants => then there are
            // 20 tokens not distributed which remain in the contract
            uint256 claimantCut = (remainingRewards - managerCut) /
                i_players.length;
            for (uint256 i = 0; i < claimants.length; i++) {
                _transferReward(claimants[i], claimantCut);
            }
        }
    }

    // @audit-info natspec ??
    function _transferReward(address player, uint256 reward) internal {
        i_token.transfer(player, reward);
    }

    function getToken() public view returns (IERC20) {
        return i_token;
    }

    function checkCut(address player) public view returns (uint256) {
        return playersToRewards[player];
    }

    function getRemainingRewards() public view returns (uint256) {
        return remainingRewards;
    }
}
