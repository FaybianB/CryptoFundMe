// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { CryptoFundMeHarness } from "./harnesses/CryptoFundMeHarness.sol";

contract CryptoFundMeTestHarness is Test {
    CryptoFundMeHarness cryptoFundMeHarness;

    function setUp() public {
        cryptoFundMeHarness = new CryptoFundMeHarness();
    }

    function testSetFeeTo(address newFeeTo) external {
        cryptoFundMeHarness.setFeeTo(newFeeTo);

        assertEq(newFeeTo, cryptoFundMeHarness.exposed_feeTo(), "Only owner can set the fee to address");
    }

    function testSetFeeToRevertWhenNotOwner(address newFeeTo, address notOwner) external {
        vm.prank(notOwner);

        vm.expectRevert("Only owner can set the fee to address");

        cryptoFundMeHarness.setFeeTo(newFeeTo);
    }
}