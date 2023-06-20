// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {Upgradable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/upgradable/Upgradable.sol";
import {StringToAddress, AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract PacManNftLinker is ERC721URIStorage, AxelarExecutable, Upgradable {
    using StringToAddress for string;
    using AddressToString for address;

    error AlreadyInitialized();

    bytes32 internal constant CONTRACT_ID = keccak256("token-linker");
    mapping(uint256 => bytes) public original; //abi.encode(originaChain, operator, tokenId);
    mapping(address => uint256) public winners; // Mapping to store winners and their token IDs
    string public chainName; //To check if we are the source chain.
    IAxelarGasService public immutable gasService;

    constructor(
        address gteway_,
        address gasReceiver_
    ) ERC721("Axelar NFT Linker", "ANL") AxelarExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_);
    }

    function _setup(bytes calldata params) internal override {
        string memory chainName_ = abi.decode(params, (string));
        if (bytes(chainName).length != 0) revert AlreadyInitialized();
        chainName = chainName_;
    }

    function contractId() external pure override returns (bytes32) {
        return CONTRACT_ID;
    }

    //The main function users will interact with.
    function sendNFT(
        address operator,
        uint256 tokenId,
        string memory destinationChain,
        address destinationAddress
    ) external payable {
        //If we are the operator then this is a minted token that lives remotely.
        if (operator == address(this)) {
            require(ownerOf(tokenId) == _msgSender(), "NOT_YOUR_TOKEN");
            _sendMintedToken(tokenId, destinationChain, destinationAddress);
        } else {
            IERC721(operator).transferFrom(
                _msgSender(),
                address(this),
                tokenId
            );
            _sendNativeToken(
                operator,
                tokenId,
                destinationChain,
                destinationAddress
            );