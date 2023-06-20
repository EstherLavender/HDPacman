// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';
import {IAxelarGateway} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import {IAxelarGasService} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';

contract PacmanRewardSender {
    IAxelarGasService immutable gasService;
    IAxelarGateway immutable gateway;

    constructor(address _gateway, address _gasReceiver) {
        gateway = IAxelarGateway(_gateway);
        gasService = IAxelarGasService(_gasReceiver);
    }

    function sendReward(
        string calldata destinationChain,
        string calldata destinationAddress,
        address[] calldata playerAddresses,
        string calldata tokenSymbol,
        uint256 rewardAmount
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            rewardAmount
        );
        IERC20(tokenAddress).approve(address(gateway), rewardAmount);
        bytes memory payload = abi.encode(playerAddresses);
        if (msg.value > 0) {
            gasService.payNativeGasForContractCallWithToken{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                tokenSymbol,
                rewardAmount,
                msg.sender
            );
        }
        gateway.callContractWithToken(
            destinationChain,
            destinationAddress,
            payload,
            tokenSymbol,
            rewardAmount
        );
    }
}
