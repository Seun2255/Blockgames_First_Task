// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    event Stake(address, uint256);
    mapping(address => uint256) public balances;
    uint256 public constant threshold = 1 ether;
    uint256 public deadline = block.timestamp + 72 hours;
    bool openForWithdraw;
    bool executed = false;

    modifier notCompleted() {
        bool next = exampleExternalContract.completed();
        require(!next, "can't execute or withdraw");
        _;
    }

    // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
    //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
    function stake() public payable notCompleted {
        balances[msg.sender] += msg.value;
        balances[address(this)] += msg.value;

        emit Stake(msg.sender, msg.value);
    }

    function stake(address from, uint256 amount) private {
        balances[from] += amount;
        balances[address(this)] += amount;

        emit Stake(from, amount);
    }

    // After some `deadline` allow anyone to call an `execute()` function
    //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
    function execute() public notCompleted {
        require(block.timestamp >= deadline, "It's not yet time");
        if (balances[address(this)] >= threshold) {
            exampleExternalContract.complete{value: address(this).balance}();
            openForWithdraw = false;
        } else {
            openForWithdraw = true;
        }
    }

    // Add a `withdraw()` function to let users withdraw their balance
    function withdraw() public payable notCompleted {
        require(openForWithdraw, "It's not yet time");
        (bool sent, ) = msg.sender.call{value: balances[msg.sender]}("");
        balances[msg.sender] = 0;
        require(sent, "Failed to send Ether");
    }

    // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        } else {
            return deadline - block.timestamp;
        }
    }

    // Add the `receive()` special function that receives eth and calls stake()
    receive() external payable notCompleted {
        stake(msg.sender, msg.value);
    }
}
