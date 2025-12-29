// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Chatroom} from "./chatRoom.sol";
import "./UltraVerifier.sol";

// Note: Pedersen hash should match the circuit implementation
// For production, use a proper Pedersen hash library
library PedersenHash {
    // Simplified pedersen - replace with actual Pedersen implementation
    // that matches the circuit's std::hash::pedersen_hash
    function hash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        // This is a placeholder - in production, use proper Pedersen hash
        // that matches Noir's std::hash::pedersen_hash implementation
        return keccak256(abi.encodePacked(left, right));
    }

    function hash(bytes32 value) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(value));
    }
}

contract Chatsystem {
    address owner;
    string name;
    string description;
    bool public pause;
    IVerifier public verifier;
    mapping(bytes32 => bool) public usedNullifiers;
    bytes32[] public commitments;

    uint256 public constant TREE_HEIGHT = 3;
    uint256 public constant MAX_LEAVES = 1 << TREE_HEIGHT;

    bytes32[TREE_HEIGHT] public filledSubtrees;
    bytes32[TREE_HEIGHT] public zeros;

    bytes32 public currentRoot;
    uint256 public nextLeafIndex;

    constructor(
        string memory _name,
        string memory _description,
        address _verifierAddress
    ) {
        owner = msg.sender;
        name = _name;
        description = _description;
        pause = false;
        verifier = IVerifier(_verifierAddress);

        // Initialize zero values for Merkle tree using same hash as circuit
        zeros[0] = bytes32(0);
        for (uint256 i = 1; i < TREE_HEIGHT; i++) {
            zeros[i] = PedersenHash.hash(zeros[i - 1], zeros[i - 1]);
        }

        for (uint256 i = 0; i < TREE_HEIGHT; i++) {
            filledSubtrees[i] = zeros[i];
        }

        currentRoot = zeros[TREE_HEIGHT - 1];
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier notpause() {
        require(pause == false, "chatsystem is paused");
        _;
    }

    struct ChatRoom {
        address roomAdd;
        string name;
    }

    ChatRoom[] public chatRooms;

    mapping(string => address) public roomByName;

    function createChatRoom(
        string memory _name,
        string memory _description
    ) external notpause {
        require(bytes(_name).length <= 30, "name is too large");
        require(roomByName[_name] == address(0), "name is taken");
        Chatroom newChatroom = new Chatroom(_name, _description);
        address roomAdd = address(newChatroom);
        chatRooms.push(ChatRoom(roomAdd, _name));
        roomByName[_name] = roomAdd;
    }

    function postMessageRelayed(
        address _room,
        string calldata _content,
        string calldata _alias
    ) external {
        Chatroom(_room).createMessage(_content, _alias);
    }

    function postMessageRelayed(
        address _room,
        string calldata _content,
        string calldata _alias,
        uint256 _daysToSend
    ) external {
        Chatroom(_room).createFutureMessage(_content, _alias, _daysToSend);
    }

    // Client must generate commitment matching the circuit:
    // commitment = PedersenHash(secret, nullifier)
    // nullifierHash = PedersenHash(nullifier)
    // The commitment is stored in the Merkle tree
    function depositToGlobalVault(bytes32 _commitment) external payable {
        require(msg.value == 0.1 ether, "Use standard denominations");
        commitments.push(_commitment);
        require(nextLeafIndex < MAX_LEAVES, "Vault full");

        uint256 currentIndex = nextLeafIndex;
        nextLeafIndex++;
        bytes32 currentLevelHash = _commitment;
        bytes32 left;
        bytes32 right;

        for (uint256 i = 0; i < TREE_HEIGHT; i++) {
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros[i];
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }

            currentLevelHash = PedersenHash.hash(left, right);
            currentIndex /= 2;
        }

        currentRoot = currentLevelHash;
    }

    function anonymousFund(
        address _chatroomAdd,
        address _messageAdd,
        bytes calldata _zkProof,
        bytes32 _nullifierHash,
        bytes32 _providedRoot
    ) external {
        require(_providedRoot == currentRoot, "Root mismatch: proof expired");
        require(!usedNullifiers[_nullifierHash], "Note already spent");

        // Prepare Public Inputs: [root, nullifier_hash]
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = _providedRoot;
        publicInputs[1] = _nullifierHash;

        // Call the linked UltraVerifier contract
        bool isValid = verifier.verify(_zkProof, publicInputs);
        require(isValid, "Invalid ZK Proof");

        usedNullifiers[_nullifierHash] = true;

        // Trigger the cross-contract call to the chatroom
        Chatroom(_chatroomAdd).receiveVaultFunding{value: 0.1 ether}(
            _messageAdd
        );
    }

    function getAllRooms() public view returns (ChatRoom[] memory) {
        return chatRooms;
    }

    function getRoomAdd(string memory _roomName) public view returns (address) {
        require(roomByName[_roomName] != address(0), "no such room exist");
        return roomByName[_roomName];
    }

    function togglePause() external onlyOwner {
        pause = !pause;
    }
}
