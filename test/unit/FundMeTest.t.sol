//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant MINIMUM_USD = 5e18;
    uint256 constant VERSION = 4;
    uint256 constant INITIAL_VALUE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, INITIAL_VALUE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), MINIMUM_USD);  
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testGetVersion() public view{
        uint256 version = fundMe.getVersion();
        assertEq(version, VERSION);
    }

    function testFundFailWithoutEnoughEth() public{
        vm.expectRevert();
        fundMe.fund();
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testFundUpdateFundedDataStructure() public funded {
        assertEq(fundMe.getAddressToAmountFunded(USER), SEND_VALUE);  
    }

    function testFunderSetToArrayOfFunders() public funded {
        assertEq(fundMe.getFunder(0), USER);
    }

    function testNotOwnerWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdraw() public funded { //modified
        address owner = fundMe.getOwner();
        vm.prank(owner);
        fundMe.withdraw();
        assertEq(fundMe.getAddressToAmountFunded(USER), 0);
    }

    function testWithdrawWithASingleFunder() public funded {
        uint256 initialOwnerBalance = fundMe.getOwner().balance;
        uint256 initialFundMeBalance = address(fundMe).balance;

        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 finalOwnerBalance = fundMe.getOwner().balance;
        uint256 finalFundMeBalance = address(fundMe).balance;
        assertEq(finalFundMeBalance, 0);
        assertEq(finalOwnerBalance, initialOwnerBalance + initialFundMeBalance);
    }

    function testWithdrawFromMultipleFunders() public funded { 
        uint160 noOfFunders = 5;
        uint160 startingFunderIndex = 1;
        for(uint160 i = startingFunderIndex; i < noOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 initialOwnerBalance = fundMe.getOwner().balance;
        uint256 initialFundMeBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        assertEq(address(fundMe).balance, 0);
        assertEq(initialOwnerBalance + initialFundMeBalance, fundMe.getOwner().balance);
    }

}