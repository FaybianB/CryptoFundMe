// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { CryptoFundMe } from "../src/CryptoFundMe.sol";

contract CryptoFundMeTest is Test {
    CryptoFundMe cryptoFundMe;

    event CampaignCreated(address indexed owner, uint256 indexed campaignId);

    event Donated(address indexed donator, uint256 indexed campaignId, uint256 amountDonated);

    function setUp() public {
        cryptoFundMe = new CryptoFundMe();
    }

    function testCreateCampaign(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image
    ) public {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);

        vm.expectEmit(true, true, true, true);

        uint256 expectedCampaignId = 0;

        emit CampaignCreated(address(this), expectedCampaignId);

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        (
            address _owner,
            uint256 _targetAmount,
            uint256 _deadline,
            ,
            string memory _title,
            string memory _description,
            string memory _image
        ) = cryptoFundMe.campaigns(campaignId);

        assertEq(_owner, address(this), "The campaign's owner was set as expected");
        assertEq(_targetAmount, targetAmount, "The campaign's target amount was set as expected");
        assertEq(_deadline, deadline, "The campaign's deadline was set as expected");
        assertEq(_title, title, "The campaign's title was set as expected");
        assertEq(_description, description, "The campaign's description was set as expected");
        assertEq(_image, image, "The campaign's image was set as expected");
    }

    function testCreateCampaignRevertWhenDeadlineHasPassed(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image
    ) public {
        vm.assume(deadline <= block.timestamp);
        vm.assume(targetAmount > 0);

        vm.expectRevert("The deadline should be a date in the future.");

        cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
    }

    function testCreateCampaignRevertWhenTargetAmountIsZero(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image
    ) public {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount == 0);

        vm.expectRevert("The target amount should be greater than 0.");

        cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
    }

    function testDonateToCampaign(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);

        vm.deal(address(this), donationAmount);

        cryptoFundMe.donateToCampaign{value: donationAmount}(campaignId);

        (,,, uint256 amountCollected,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(donationAmount, amountCollected, "Campaign's amount collected did not inrease as expected");
    }

    receive() payable external {}
}
