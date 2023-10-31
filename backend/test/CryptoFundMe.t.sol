// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { CryptoFundMe } from "../src/CryptoFundMe.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";
import { CrowdfundToken } from "../utils/CrowdfundToken.sol";

contract CryptoFundMeTest is Test {
    CryptoFundMe cryptoFundMe;

    CrowdfundToken crowdfundToken;

    address ALICE;

    event CampaignCreated(address indexed owner, uint256 indexed campaignId);

    event Donated(address indexed donator, uint256 indexed campaignId, uint256 amountDonated);

    function setUp() public {
        cryptoFundMe = new CryptoFundMe();
        ALICE = makeAddr("ALICE");

        vm.prank(ALICE);

        crowdfundToken = new CrowdfundToken();
    }

    function testCreateCampaignETH(
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
            address _creator,
            address _acceptedToken,
            uint256 _targetAmount,
            uint256 _deadline,
            ,
            string memory _title,
            string memory _description,
            string memory _image
        ) = cryptoFundMe.campaigns(campaignId);

        assertEq(_creator, address(this), "The campaign's owner was set as expected");
        assertEq(_acceptedToken, cryptoFundMe.ETHER_ADDRESS(), "Token address should be set to Ether address");
        assertEq(_targetAmount, targetAmount, "The campaign's target amount was set as expected");
        assertEq(_deadline, deadline, "The campaign's deadline was set as expected");
        assertEq(_title, title, "The campaign's title was set as expected");
        assertEq(_description, description, "The campaign's description was set as expected");
        assertEq(_image, image, "The campaign's image was set as expected");
    }

    function testCreateCampaignERC20(
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

        uint256 campaignId =
            cryptoFundMe.createCampaign(address(crowdfundToken), title, description, targetAmount, deadline, image);
        (
            address _creator,
            address _acceptedToken,
            uint256 _targetAmount,
            uint256 _deadline,
            ,
            string memory _title,
            string memory _description,
            string memory _image
        ) = cryptoFundMe.campaigns(campaignId);

        assertEq(_creator, address(this), "The campaign's owner was set as expected");
        assertEq(_acceptedToken, address(crowdfundToken), "Token address should be set to Ether address");
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

        vm.expectRevert("The deadline should be a date in the future");

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

        vm.expectRevert("The target amount should be greater than 0");

        cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
    }

    function testDonateEtherToCampaign(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);
        vm.assume(donationAmount > 0);

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        UD60x18 feeAmount = cryptoFundMe.calculateFee(ud(donationAmount));
        uint256 netDonationAmount = unwrap(ud(donationAmount).sub(feeAmount));

        vm.deal(address(this), donationAmount);

        cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);

        (,,,, uint256 amountCollected,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(netDonationAmount, amountCollected, "Campaign's amount collected did not increase as expected");
    }

    function testDonateEtherToCampaignRevertWhenNoEtherSent(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image
    ) external {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);

        uint256 donationAmount = 0;
        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);

        vm.expectRevert("No Ether sent for donation");

        cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);
    }

    function testDonateERC20ToCampaign(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);

        uint256 campaignId =
            cryptoFundMe.createCampaign(address(crowdfundToken), title, description, targetAmount, deadline, image);
        UD60x18 feeAmount = cryptoFundMe.calculateFee(ud(donationAmount));
        uint256 netDonationAmount = unwrap(ud(donationAmount).sub(feeAmount));

        vm.startPrank(ALICE);

        crowdfundToken.approve(address(cryptoFundMe), donationAmount);

        cryptoFundMe.donateERC20ToCampaign(campaignId, crowdfundToken, donationAmount);

        (,,,, uint256 amountCollected,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(netDonationAmount, amountCollected, "Campaign's amount collected did not increase as expected");
    }

    receive() external payable { }
}
