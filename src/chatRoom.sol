// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Message} from "./message.sol";

contract Chatroom{
    address public owner;
    string public name;
    string public description;
    bool public pause;

    
    struct chatMessage{
        address messageAdd;
    }
    struct FutureMessage{
        address messageAdd;
        uint256 sendingTime;
    }

    chatMessage[] public chats;
    FutureMessage[] internal Futurechats;


    constructor(
        string memory _name,
        string memory _description
    ){
        owner = msg.sender;
        name = _name;
        description = _description;
        pause = false;
        Futurechats.push(FutureMessage(owner,0));
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier notpause(){
        require(pause == false, "chatroom is paused");
        _;
    }

    function createMessage(
        string memory _content,
        string memory _name
    )public notpause{
        Message newMessage = new Message(_content,_name,0,owner);
        address messageAdd = address(newMessage);
        chats.push(chatMessage(messageAdd));
    }
    function createMessage(
        string memory _content,
        string memory _name,
        address fundmeAdd
    )public notpause{
        Message newMessage = new Message(_content,_name,0,fundmeAdd);
        address messageAdd = address(newMessage);
        chats.push(chatMessage(messageAdd));
    }
    function createFutureMessage(
        string memory _content,
        string memory _name,
        uint256 _daysToSend
    )public notpause{
        Message newMessage = new Message(_content,_name,_daysToSend,owner);
        address messageAdd = address(newMessage);
        uint256 sendingTime = block.timestamp + (_daysToSend * 1 days);
        scheduleFutureMessage(messageAdd, sendingTime);
    }
    function createFutureMessage(
        string memory _content,
        string memory _name,
        uint256 _daysToSend,
        address fundmeAdd
    )public notpause{
        Message newMessage = new Message(_content,_name,_daysToSend,fundmeAdd);
        address messageAdd = address(newMessage);
        uint256 sendingTime = block.timestamp + (_daysToSend * 1 days);
        scheduleFutureMessage(messageAdd, sendingTime);
    }

    function scheduleFutureMessage(address messageAdd , uint256 _sendingTime) internal {
        Futurechats.push(FutureMessage(messageAdd , _sendingTime));
        _bubbleUp(Futurechats.length - 1);
    }

    function sendFutureMessage() public {
        require(Futurechats.length > 1, "Queue empty");
        require(Futurechats[1].sendingTime <= block.timestamp, "can't send before sending time");
        while(Futurechats.length > 1 && Futurechats[1].sendingTime <= block.timestamp){
            chats.push(chatMessage(Futurechats[1].messageAdd));
            popMessage();
        }
    }

    function _bubbleUp(uint256 _index) internal {
        while (_index > 1 && Futurechats[_index].sendingTime < Futurechats[_index / 2].sendingTime) {
            _swap(_index, _index / 2);
            _index = _index / 2;
        }
    }

    function popMessage() internal {
        require(Futurechats.length > 1, "Underflow");
        
        // Move last element to root and shrink
        Futurechats[1] = Futurechats[Futurechats.length - 1];
        Futurechats.pop();
        
        if (Futurechats.length > 1) {
            _bubbleDown(1);
        }
    }

    function _bubbleDown(uint256 _index) internal {
        while (_index * 2 < Futurechats.length) {
            uint256 j = _index * 2;
            // Pick the smaller child
            if (j + 1 < Futurechats.length && Futurechats[j+1].sendingTime < Futurechats[j].sendingTime) j++;
            
            if (Futurechats[_index].sendingTime <= Futurechats[j].sendingTime) break;
            
            _swap(_index, j);
            _index = j;
        }
    }

    function _swap(uint256 i, uint256 j) internal {
        FutureMessage memory temp = Futurechats[i];
        Futurechats[i] = Futurechats[j];
        Futurechats[j] = temp;
    }

    function receiveVaultFunding(address _messageAdd) external payable {
        // Only the global factory can call this to move vault funds
        require(msg.sender == address(owner), "Unauthorized");
        
        // Trigger the funding on the Message contract
        Message(_messageAdd).fund{value: msg.value}();
    }

    function getAllChats() public returns (chatMessage[] memory){
        if (Futurechats.length > 1 && Futurechats[1].sendingTime <= block.timestamp) {
            sendFutureMessage();
        }
        return chats;
    }
    

    function togglePause() external onlyOwner {
        pause = !pause; 
    }
}

