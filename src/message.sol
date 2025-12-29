// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Message{
    string public content;
    string public senderName;
    uint256 public sendingTime;
    address internal fundmeAdd;

    constructor(
        string memory _content,
        string memory _name,
        uint256 _daysToSend,
        address _paymentOwner
    ){
        content = _content;
        senderName = _name;
        sendingTime = block.timestamp + (_daysToSend * 1 days);
        fundmeAdd = _paymentOwner;
    }

    function fund() public payable {
        require(msg.value > 0 , "require non zero payment");
        require(fundmeAdd != msg.sender , "not expecting payment");
        (bool success, ) = payable(fundmeAdd).call{value: msg.value}("");
        require(success, "transfer failed");
    }


}