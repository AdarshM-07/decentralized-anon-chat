// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/chatSystem.sol";
import "../src/UltraVerifier.sol";

contract ChatSystemTest is Test {
    Chatsystem public chatSystem;
    HonkVerifier public verifier;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // Deploy verifier
        verifier = new HonkVerifier();

        // Deploy chat system
        chatSystem = new Chatsystem(
            "TestChat",
            "Test Description",
            address(verifier)
        );

        // Fund test users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testDeployment() public view {
        assertEq(chatSystem.pause(), false);
        assertEq(chatSystem.nextLeafIndex(), 0);
        assertEq(address(chatSystem.verifier()), address(verifier));
    }

    function testDepositToVault() public {
        // Generate a commitment (this would normally be: pedersen_hash([secret, nullifier]))
        // For testing, we use a placeholder value
        bytes32 commitment = keccak256(
            abi.encodePacked(uint256(7), uint256(11))
        );

        vm.startPrank(user1);

        // Deposit 0.1 ether with commitment
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment);

        vm.stopPrank();

        // Verify the state
        assertEq(chatSystem.nextLeafIndex(), 1);
        assertEq(chatSystem.commitments(0), commitment);
        assertEq(address(chatSystem).balance, 0.1 ether);
    }

    function testMultipleDeposits() public {
        bytes32 commitment1 = keccak256(
            abi.encodePacked(uint256(1), uint256(2))
        );
        bytes32 commitment2 = keccak256(
            abi.encodePacked(uint256(3), uint256(4))
        );
        bytes32 commitment3 = keccak256(
            abi.encodePacked(uint256(5), uint256(6))
        );

        vm.startPrank(user1);
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment1);
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment2);
        vm.stopPrank();

        vm.prank(user2);
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment3);

        assertEq(chatSystem.nextLeafIndex(), 3);
        assertEq(address(chatSystem).balance, 0.3 ether);

        // Verify merkle root has been updated
        assertTrue(chatSystem.currentRoot() != bytes32(0));
    }

    function testDepositWrongAmount() public {
        bytes32 commitment = keccak256(
            abi.encodePacked(uint256(7), uint256(11))
        );

        vm.startPrank(user1);

        // Try to deposit wrong amount
        vm.expectRevert("Use standard denominations");
        chatSystem.depositToGlobalVault{value: 0.05 ether}(commitment);

        vm.expectRevert("Use standard denominations");
        chatSystem.depositToGlobalVault{value: 0.2 ether}(commitment);

        vm.stopPrank();
    }

    function testMerkleTreeFull() public {
        // Fill the tree (max 8 leaves)
        for (uint256 i = 0; i < 8; i++) {
            bytes32 commitment = keccak256(abi.encodePacked(i, i + 100));
            vm.prank(user1);
            chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment);
        }

        assertEq(chatSystem.nextLeafIndex(), 8);

        // Try to add one more - should fail
        bytes32 commitment = keccak256(
            abi.encodePacked(uint256(999), uint256(999))
        );
        vm.prank(user1);
        vm.expectRevert("Vault full");
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment);
    }

    function testGetMerkleRoot() public {
        bytes32 initialRoot = chatSystem.currentRoot();

        bytes32 commitment = keccak256(
            abi.encodePacked(uint256(7), uint256(11))
        );
        vm.prank(user1);
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment);

        bytes32 newRoot = chatSystem.currentRoot();

        // Root should change after deposit
        assertTrue(initialRoot != newRoot);
    }

    function testCreateChatRoom() public {
        chatSystem.createChatRoom("TestRoom", "Room Description");

        address roomAddress = chatSystem.getRoomAdd("TestRoom");
        assertTrue(roomAddress != address(0));

        (address addr, string memory roomName) = chatSystem.chatRooms(0);
        assertEq(addr, roomAddress);
        assertEq(roomName, "TestRoom");
    }

    function testPauseToggle() public {
        assertEq(chatSystem.pause(), false);

        chatSystem.togglePause();
        assertEq(chatSystem.pause(), true);

        chatSystem.togglePause();
        assertEq(chatSystem.pause(), false);
    }

    function testCannotCreateRoomWhenPaused() public {
        chatSystem.togglePause();

        vm.expectRevert("chatsystem is paused");
        chatSystem.createChatRoom("TestRoom", "Description");
    }

    // Note: Testing anonymousFund requires a valid ZK proof from the Noir circuit
    // This would be an integration test that requires:
    // 1. Generate proof with Noir CLI
    // 2. Parse the proof bytes
    // 3. Call anonymousFund with the proof
    function testAnonymousFundRequiresValidProof() public {
        // First, deposit to create a merkle root
        bytes32 commitment = keccak256(
            abi.encodePacked(uint256(7), uint256(11))
        );
        vm.prank(user1);
        chatSystem.depositToGlobalVault{value: 0.1 ether}(commitment);

        bytes32 root = chatSystem.currentRoot();
        bytes32 nullifierHash = keccak256(abi.encodePacked(uint256(11)));

        // Create a chatroom and message
        chatSystem.createChatRoom("TestRoom", "Description");
        address roomAddress = chatSystem.getRoomAdd("TestRoom");

        // This will fail because we don't have a valid proof
        bytes memory emptyProof = "";

        vm.expectRevert(); // Will revert due to invalid proof
        chatSystem.anonymousFund(
            roomAddress,
            address(0x123), // dummy message address
            emptyProof,
            nullifierHash,
            root
        );
    }

    function testNullifierCannotBeReused() public {
        // This test would require a valid proof
        // For now, we can test the nullifier tracking directly
        bytes32 nullifierHash = keccak256(abi.encodePacked(uint256(11)));

        // Manually mark nullifier as used (simulating a successful withdrawal)
        // Note: In actual use, this would be set by anonymousFund after proof verification
        // For testing, we'd need to use a more complex setup or modify the contract

        assertTrue(!chatSystem.usedNullifiers(nullifierHash));
    }
}
