// SPDX-License-Identifier: MIT
// @audit-info It's better to have static solidity version solidity 0.8.20
pragma solidity ^0.8.20;

import {Pot} from "./Pot.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ContestManager is Ownable {
    address[] public contests;
    mapping(address => uint256) public contestToTotalRewards;

    error ContestManager__InsufficientFunds();

    constructor() Ownable(msg.sender) {}

    function createContest(address[] memory players, uint256[] memory rewards, IERC20 token, uint256 totalRewards)
        public
        onlyOwner
        returns (address)
    {
        // Create a new Pot contract
        // @audit-low we are not verifying the array length of players and rewards are equal
        Pot pot = new Pot(players, rewards, token, totalRewards);
        contests.push(address(pot));
        contestToTotalRewards[address(pot)] = totalRewards;
        return address(pot);
    }

    function fundContest(uint256 index) public onlyOwner {
        Pot pot = Pot(contests[index]);
        IERC20 token = pot.getToken();
        uint256 totalRewards = contestToTotalRewards[address(pot)];

        if (token.balanceOf(msg.sender) < totalRewards) {
            revert ContestManager__InsufficientFunds();
        }
        // @audit-medium We don't verify if the transfer is successfull, so the 
        // transaction is not reverted even the funding is failed
        token.transferFrom(msg.sender, address(pot), totalRewards);
        // events are welcome here
    }

    function getContests() public view returns (address[] memory) {
        return contests;
    }

    function getContestTotalRewards(address contest) public view returns (uint256) {
        return contestToTotalRewards[contest];
    }

    function getContestRemainingRewards(address contest) public view returns (uint256) {
        Pot pot = Pot(contest);
        return pot.getRemainingRewards();
    }

    function closeContest(address contest) public onlyOwner {
        _closeContest(contest);
    }

    function _closeContest(address contest) internal {
        Pot pot = Pot(contest);
        pot.closePot();
    }
}
