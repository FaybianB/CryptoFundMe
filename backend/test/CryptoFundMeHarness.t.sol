// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import { CryptoFundMeHarness } from "./harnesses/CryptoFundMeHarness.sol";
import { CryptoFundMe, Unauthorized } from "../src/CryptoFundMe.sol";

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
        vm.assume(notOwner != address(this));

        vm.prank(notOwner);

        vm.expectRevert(Unauthorized.selector);

        cryptoFundMeHarness.setFeeTo(newFeeTo);
    }
}
