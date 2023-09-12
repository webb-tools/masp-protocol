/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "../interfaces/IRewardSwap.sol";
import "./RewardManager.sol";
//import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardSwap is IRewardSwap {
	//using SafeERC20 for IERC20;

	uint256 public constant DURATION = 365 days;

	IERC20 public immutable tangle;
	RewardManager public immutable manager;
	uint256 public immutable startTimestamp;
	uint256 public immutable initialLiquidity;
	uint256 public immutable liquidity;
	uint256 public tokensSold;
	uint256 public poolWeight;

	event Swap(address indexed recipient, uint256 AP, uint256 TNT);
	event PoolWeightUpdated(uint256 newWeight);

	modifier onlyManager() {
		require(msg.sender == address(manager), "Only Miner contract can call");
		_;
	}

	constructor(
		address _tangle,
		address _manager,
		uint256 _miningCap,
		uint256 _initialLiquidity,
		uint256 _poolWeight
	) {
		require(
			_initialLiquidity <= _miningCap,
			"Initial liquidity should be lower than mining cap"
		);
		tangle = IERC20(_tangle);
		manager = RewardManager(_manager);
		initialLiquidity = _initialLiquidity;
		liquidity = _miningCap - _initialLiquidity;
		poolWeight = _poolWeight;
		startTimestamp = getTimestamp();
	}

	function swap(address _recipient, uint256 _amount) external onlyManager returns (uint256) {
		uint256 tokens = getExpectedReturn(_amount);
		tokensSold += tokens;
		require(tangle.transfer(_recipient, tokens), "transfer failed");
		emit Swap(_recipient, _amount, tokens);
		return tokens;
	}

	function setPoolWeight(uint256 _newWeight) external onlyManager {
		poolWeight = _newWeight;
		emit PoolWeightUpdated(_newWeight);
	}

	function getExpectedReturn(uint256 _amount) public view returns (uint256) {
		// #TODO FloatMath library import
		// uint256 oldBalance = tornVirtualBalance();
		//int128 pow = FloatMath.neg(FloatMath.divu(_amount, poolWeight));
		//int128 exp = FloatMath.exp(pow);
		//uint256 newBalance = FloatMath.mulu(exp, oldBalance);
		//return oldBalance.sub(newBalance);
		return 1;
	}

	function tornVirtualBalance() public view returns (uint256) {
		uint256 passedTime = getTimestamp() - startTimestamp;
		if (passedTime < DURATION) {
			return initialLiquidity + ((liquidity * passedTime) / DURATION) - tokensSold;
		} else {
			return tangle.balanceOf(address(this));
		}
	}

	function getTimestamp() public view virtual returns (uint256) {
		return block.timestamp;
	}
}
