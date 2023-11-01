// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { CryptoFundMe, CampaignCreated, Donated, DeadlineChanged, TargetAmountChanged } from "../src/CryptoFundMe.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";
import { CrowdfundToken } from "../utils/CrowdfundToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

event Transfer(address indexed from, address indexed to, uint256 value);

contract CryptoFundMeTest is Test {
    CryptoFundMe cryptoFundMe;

    CrowdfundToken crowdfundToken;

    address DONATOR;
    address FEE_TO;

    function setUp() public {
        FEE_TO = makeAddr("FEE_TO");
        cryptoFundMe = new CryptoFundMe(FEE_TO);
        DONATOR = makeAddr("DONATOR");

        vm.prank(DONATOR);

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

        uint256 expectedCampaignId = 0;

        vm.expectEmit(true, true, true, true);

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
        (address creator,,,,,,,) = cryptoFundMe.campaigns(campaignId);

        startHoax(DONATOR, donationAmount);

        uint256 donatorBalanceBefore = address(DONATOR).balance;
        uint256 creatorBalanceBefore = address(creator).balance;
        uint256 feeToBalanceBefore = address(FEE_TO).balance;

        vm.expectEmit(true, true, true, true);

        emit Donated(DONATOR, campaignId, netDonationAmount);

        uint256 donationId = cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);

        vm.stopPrank();

        (,,,, uint256 amountCollected,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(netDonationAmount, amountCollected, "Campaign's amount collected did not increase as expected");

        {
            uint256 donatorBalanceAfter = address(DONATOR).balance;
            uint256 creatorBalanceAfter = address(creator).balance;
            uint256 feeToBalanceAfter = address(FEE_TO).balance;

            assertEq(
                donatorBalanceAfter,
                donatorBalanceBefore - donationAmount,
                "Donator's balance did not decrease as expected"
            );
            assertEq(
                creatorBalanceAfter,
                creatorBalanceBefore + netDonationAmount,
                "Creator's balance did not increase as expected"
            );
            assertEq(
                feeToBalanceAfter,
                feeToBalanceBefore + unwrap(feeAmount),
                "Fee receiver's balance did not increase as expected"
            );
        }

        (address donator, uint256 amountDonated) = cryptoFundMe.donations(campaignId, donationId);

        // Assert that the storage variables update correctly
        assertEq(donator, DONATOR, "Donator was not stored correctly");
        assertEq(amountDonated, netDonationAmount, "Donation amount was not stored correctly");
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

    function testDonateEtherToCampaignRevertWhenCampaignDeadlinePassed(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        vm.assume(targetAmount > 0);
        vm.assume(donationAmount > 0);

        deadline = bound(deadline, block.timestamp + 1, type(uint256).max - 1);
        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);

        startHoax(DONATOR, donationAmount);

        vm.warp(deadline + 1);

        vm.expectRevert("The campaign has ended");

        cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);

        vm.stopPrank();
    }

    function testDonateEtherToCampaignRevertWhenTargetAmountReached(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        targetAmount = bound(targetAmount, 1, type(uint256).max / 3);
        donationAmount = bound(donationAmount, targetAmount * 2, type(uint256).max - 1);

        vm.assume(deadline > block.timestamp);

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);

        startHoax(DONATOR, type(uint256).max);

        cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);

        vm.expectRevert("The campaign has reached it's goal");

        cryptoFundMe.donateEtherToCampaign{ value: 1 }(campaignId);

        vm.stopPrank();
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
        (address creator,,,,,,,) = cryptoFundMe.campaigns(campaignId);
        uint256 donatorBalanceBefore = crowdfundToken.balanceOf(DONATOR);
        uint256 creatorBalanceBefore = crowdfundToken.balanceOf(creator);
        uint256 feeToBalanceBefore = crowdfundToken.balanceOf(FEE_TO);

        vm.startPrank(DONATOR);

        crowdfundToken.approve(address(cryptoFundMe), donationAmount);

        vm.expectEmit(true, true, true, true);

        emit Transfer(DONATOR, FEE_TO, unwrap(feeAmount));

        vm.expectEmit(true, true, true, true);

        emit Transfer(DONATOR, creator, netDonationAmount);

        vm.expectEmit(true, true, true, true);

        emit Donated(DONATOR, campaignId, netDonationAmount);

        uint256 donationId = cryptoFundMe.donateERC20ToCampaign(campaignId, crowdfundToken, donationAmount);

        vm.stopPrank();

        (,,,, uint256 amountCollected,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(netDonationAmount, amountCollected, "Campaign's amount collected did not increase as expected");

        uint256 donatorBalanceAfter = crowdfundToken.balanceOf(DONATOR);
        uint256 creatorBalanceAfter = crowdfundToken.balanceOf(creator);
        uint256 feeToBalanceAfter = crowdfundToken.balanceOf(FEE_TO);

        assertEq(
            donatorBalanceAfter, donatorBalanceBefore - donationAmount, "Donator's balance did not decrease as expected"
        );
        assertEq(
            creatorBalanceAfter,
            creatorBalanceBefore + netDonationAmount,
            "Creator's balance did not increase as expected"
        );
        assertEq(
            feeToBalanceAfter,
            feeToBalanceBefore + unwrap(feeAmount),
            "Fee receiver's balance did not increase as expected"
        );

        (address donator, uint256 amountDonated) = cryptoFundMe.donations(campaignId, donationId);

        // Assert that the storage variables update correctly
        assertEq(donator, DONATOR, "Donator was not stored correctly");
        assertEq(amountDonated, netDonationAmount, "Donation amount was not stored correctly");
    }

    function testDonateERC20ToCampaignRevertWhenUnacceptableToken(
        address tokenAddress,
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        vm.assume(tokenAddress != address(crowdfundToken));
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);
        vm.assume(donationAmount > 0);

        uint256 campaignId =
            cryptoFundMe.createCampaign(address(crowdfundToken), title, description, targetAmount, deadline, image);

        vm.expectRevert("This campaign does not accept donations of this token");

        cryptoFundMe.donateERC20ToCampaign(campaignId, IERC20(tokenAddress), donationAmount);
    }

    function testDonateERC20ToCampaignRevertWhenCampaignDeadlinePassed(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        vm.assume(targetAmount > 0);
        vm.assume(donationAmount > 0);

        deadline = bound(deadline, block.timestamp + 1, type(uint256).max - 1);
        uint256 campaignId =
            cryptoFundMe.createCampaign(address(crowdfundToken), title, description, targetAmount, deadline, image);

        vm.warp(deadline + 1);

        vm.expectRevert("The campaign has ended");

        cryptoFundMe.donateERC20ToCampaign(campaignId, crowdfundToken, donationAmount);
    }

    function testDonateERC20ToCampaignRevertWhenTargetAmountReached(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmount
    ) external {
        targetAmount = bound(targetAmount, 1, type(uint256).max / 3);

        vm.assume(deadline > block.timestamp);
        vm.assume(donationAmount > targetAmount * 2);

        uint256 campaignId =
            cryptoFundMe.createCampaign(address(crowdfundToken), title, description, targetAmount, deadline, image);

        vm.startPrank(DONATOR);

        crowdfundToken.approve(address(cryptoFundMe), donationAmount);

        cryptoFundMe.donateERC20ToCampaign(campaignId, crowdfundToken, donationAmount);

        vm.expectRevert("The campaign has reached it's goal");

        cryptoFundMe.donateERC20ToCampaign(campaignId, crowdfundToken, 1);

        vm.stopPrank();
    }

    function testGetCampaignDonations(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 donationAmountOne,
        uint256 donationAmountTwo,
        uint256 donationAmountThree
    ) public {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount >= 3);

        donationAmountOne = bound(donationAmountOne, 1, targetAmount / 3);
        donationAmountTwo = bound(donationAmountOne, 1, targetAmount / 3);
        donationAmountThree = bound(donationAmountOne, 1, targetAmount / 3);
        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        UD60x18 feeAmountOne = cryptoFundMe.calculateFee(ud(donationAmountOne));
        uint256 netDonationAmountOne = unwrap(ud(donationAmountOne).sub(feeAmountOne));

        hoax(DONATOR, donationAmountOne);

        uint256 donationId = cryptoFundMe.donateEtherToCampaign{ value: donationAmountOne }(campaignId);
        address DONATOR_TWO = makeAddr("DONATOR_TWO");
        UD60x18 feeAmountTwo = cryptoFundMe.calculateFee(ud(donationAmountTwo));
        uint256 netDonationAmountTwo = unwrap(ud(donationAmountTwo).sub(feeAmountTwo));

        hoax(DONATOR_TWO, donationAmountTwo);

        uint256 donationIdTwo = cryptoFundMe.donateEtherToCampaign{ value: donationAmountTwo }(campaignId);
        address DONATOR_THREE = makeAddr("DONATOR_THREE");
        UD60x18 feeAmountThree = cryptoFundMe.calculateFee(ud(donationAmountThree));
        uint256 netDonationAmountThree = unwrap(ud(donationAmountThree).sub(feeAmountThree));

        hoax(DONATOR_THREE, donationAmountThree);

        uint256 donationIdThree = cryptoFundMe.donateEtherToCampaign{ value: donationAmountThree }(campaignId);

        CryptoFundMe.Donation[] memory donations = cryptoFundMe.getCampaignDonations(campaignId);

        assertEq(donations[donationId].donator, DONATOR, "First donator address did not match");
        assertEq(donations[donationId].donationAmount, netDonationAmountOne, "First donation amount did not match");
        assertEq(donations[donationIdTwo].donator, DONATOR_TWO, "Second donator address did not match");
        assertEq(donations[donationIdTwo].donationAmount, netDonationAmountTwo, "Second donation amount did not match");
        assertEq(donations[donationIdThree].donator, DONATOR_THREE, "Third donator address did not match");
        assertEq(
            donations[donationIdThree].donationAmount, netDonationAmountThree, "Third donation amount did not match"
        );
    }

    function testGetCampaigns(
        string memory titleOne,
        string memory titleTwo,
        string memory descriptionOne,
        string memory descriptionTwo,
        address acceptedToken,
        uint256 targetAmountOne,
        uint256 targetAmountTwo,
        uint256 deadlineOne,
        uint256 deadlineTwo,
        string memory imageOne,
        string memory imageTwo
    ) public {
        vm.assume(deadlineOne > block.timestamp);
        vm.assume(deadlineTwo > block.timestamp);
        vm.assume(targetAmountOne > 0);
        vm.assume(targetAmountTwo > 0);

        {
            address CREATOR_ONE = makeAddr("CREATOR_ONE");

            vm.prank(CREATOR_ONE);

            uint256 campaignId =
                cryptoFundMe.createCampaign(titleOne, descriptionOne, targetAmountOne, deadlineOne, imageOne);
            CryptoFundMe.Campaign[] memory campaigns = cryptoFundMe.getCampaigns();

            assertEq(campaigns[campaignId].creator, CREATOR_ONE, "The campaign's owner was not set as expected");
            assertEq(
                campaigns[campaignId].acceptedToken,
                cryptoFundMe.ETHER_ADDRESS(),
                "Token address should be set to Ether address"
            );
            assertEq(
                campaigns[campaignId].targetAmount, targetAmountOne, "The campaign's target amount was set as expected"
            );
            assertEq(campaigns[campaignId].deadline, deadlineOne, "The campaign's deadline was set as expected");
            assertEq(campaigns[campaignId].title, titleOne, "The campaign's title was set as expected");
            assertEq(
                campaigns[campaignId].description, descriptionOne, "The campaign's description was set as expected"
            );
            assertEq(campaigns[campaignId].image, imageOne, "The campaign's image was set as expected");
        }
        {
            address CREATOR_TWO = makeAddr("CREATOR_TWO");

            vm.prank(CREATOR_TWO);

            uint256 campaignId = cryptoFundMe.createCampaign(
                acceptedToken, titleTwo, descriptionTwo, targetAmountTwo, deadlineTwo, imageTwo
            );
            CryptoFundMe.Campaign[] memory campaigns = cryptoFundMe.getCampaigns();

            assertEq(campaigns[campaignId].creator, CREATOR_TWO, "The campaign's owner was not set as expected");
            assertEq(
                campaigns[campaignId].acceptedToken,
                acceptedToken,
                "Token address should be set to the accepted token address"
            );
            assertEq(
                campaigns[campaignId].targetAmount, targetAmountTwo, "The campaign's target amount was set as expected"
            );
            assertEq(campaigns[campaignId].deadline, deadlineTwo, "The campaign's deadline was set as expected");
            assertEq(campaigns[campaignId].title, titleTwo, "The campaign's title was set as expected");
            assertEq(
                campaigns[campaignId].description, descriptionTwo, "The campaign's description was set as expected"
            );
            assertEq(campaigns[campaignId].image, imageTwo, "The campaign's image was set as expected");
        }
    }

    function testChangeDeadline(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newDeadline,
        string memory reason
    ) external {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        uint256 changeFee = cryptoFundMe.changeFee();

        vm.deal(address(this), changeFee);

        vm.expectEmit(true, true, true, true);

        emit DeadlineChanged(address(this), campaignId, reason);

        cryptoFundMe.changeDeadline{ value: changeFee }(campaignId, newDeadline, reason);

        (,,, uint256 updatedDeadline,,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(updatedDeadline, newDeadline, "The campaign's deadline was not changed as expected");
    }

    function testChangeDeadlineRevertWhenDeadlinePassed(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newDeadline,
        string memory reason
    ) external {
        vm.assume(targetAmount > 0);

        deadline = bound(deadline, block.timestamp + 1, type(uint256).max - 1);
        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        uint256 changeFee = cryptoFundMe.changeFee();

        vm.deal(address(this), changeFee);

        vm.warp(deadline + 1);

        vm.expectRevert("The campaign has ended");

        cryptoFundMe.changeDeadline{ value: changeFee }(campaignId, newDeadline, reason);
    }

    function testChangeDeadlineRevertWhenTargetAmountReached(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newDeadline,
        string memory reason,
        uint256 donationAmount
    ) external {
        vm.assume(deadline > block.timestamp);

        uint256 changeFee = cryptoFundMe.changeFee();
        targetAmount = bound(targetAmount, 1, type(uint256).max / 3);
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max - 1);
        donationAmount = bound(donationAmount, targetAmount * 2, type(uint256).max - 1 - changeFee);
        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);

        vm.deal(address(this), donationAmount + changeFee);

        cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);

        vm.expectRevert("The campaign has reached it's goal");

        cryptoFundMe.changeDeadline{ value: changeFee }(campaignId, newDeadline, reason);
    }

    function testChangeDeadlineRevertWhenNotCreator(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newDeadline,
        string memory reason,
        address notCreator
    ) external {
        vm.assume(targetAmount > 0);
        vm.assume(deadline > block.timestamp);
        vm.assume(notCreator != address(this));

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        uint256 changeFee = cryptoFundMe.changeFee();

        startHoax(notCreator, changeFee);

        vm.expectRevert("Only campaign creator can execute this action");

        cryptoFundMe.changeDeadline{ value: changeFee }(campaignId, newDeadline, reason);
    }

    function testChangeTargetAmount(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newTargetAmount,
        string memory reason
    ) external {
        vm.assume(deadline > block.timestamp);
        vm.assume(targetAmount > 0);

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        uint256 changeFee = cryptoFundMe.changeFee();

        vm.deal(address(this), changeFee);

        vm.expectEmit(true, true, true, true);

        emit TargetAmountChanged(address(this), campaignId, reason);

        cryptoFundMe.changeTargetAmount{ value: changeFee }(campaignId, newTargetAmount, reason);

        (,, uint256 updatedTargetAmount,,,,,) = cryptoFundMe.campaigns(campaignId);

        assertEq(updatedTargetAmount, newTargetAmount, "The campaign's target amount was not changed as expected");
    }

    function testChangeTargetAmountRevertWhenTargetAmountReached(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newTargetAmount,
        string memory reason,
        uint256 donationAmount
    ) external {
        vm.assume(deadline > block.timestamp);

        uint256 changeFee = cryptoFundMe.changeFee();
        targetAmount = bound(targetAmount, 1, type(uint256).max / 3);
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max - 1);
        donationAmount = bound(donationAmount, targetAmount * 2, type(uint256).max - 1 - changeFee);
        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);

        vm.deal(address(this), donationAmount + changeFee);

        cryptoFundMe.donateEtherToCampaign{ value: donationAmount }(campaignId);

        vm.expectRevert("The campaign has reached it's goal");

        cryptoFundMe.changeTargetAmount{ value: changeFee }(campaignId, newTargetAmount, reason);
    }

    function testChangeTargetAmountRevertWhenNotCreator(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        string memory image,
        uint256 newTargetAmount,
        string memory reason,
        address notCreator
    ) external {
        vm.assume(targetAmount > 0);
        vm.assume(deadline > block.timestamp);
        vm.assume(notCreator != address(this));

        uint256 campaignId = cryptoFundMe.createCampaign(title, description, targetAmount, deadline, image);
        uint256 changeFee = cryptoFundMe.changeFee();

        startHoax(notCreator, changeFee);

        vm.expectRevert("Only campaign creator can execute this action");

        cryptoFundMe.changeTargetAmount{ value: changeFee }(campaignId, newTargetAmount, reason);
    }

    function testSetChangeFee(uint256 newChangeFee) external {
        cryptoFundMe.setChangeFee(newChangeFee);

        assertEq(newChangeFee, cryptoFundMe.changeFee(), "Change fee was not updated as expected");
    }

    function testSetChangeFeeRevertWhenNotOwner(uint256 newChangeFee, address notOwner) external {
        vm.prank(notOwner);

        vm.expectRevert("Only owner can set the fee to address");

        cryptoFundMe.setChangeFee(newChangeFee);
    }

    receive() external payable { }
}
