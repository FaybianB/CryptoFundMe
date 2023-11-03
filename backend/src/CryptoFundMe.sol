// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

/**
 * @dev Emitted when a new campaign is created
 * @param creator The address of the campaign creator
 * @param campaignId The ID of the newly created campaign
 */
event CampaignCreated(address indexed creator, uint256 indexed campaignId);

/**
 * @dev Emitted when a donation is made to a campaign
 * @param donator The address of the donator
 * @param campaignId The ID of the campaign to which the donation was made
 * @param amountDonated The amount of the donation
 */
event Donated(address indexed donator, uint256 indexed campaignId, uint256 amountDonated);

/**
 * @dev Emitted when the deadline of a campaign is changed
 * @param creator The address of the campaign creator
 * @param campaignId The ID of the campaign for which the deadline was changed
 * @param reason The reason for changing the deadline
 */
event DeadlineChanged(address indexed creator, uint256 indexed campaignId, string reason);

/**
 * @dev Emitted when the target amount of a campaign is changed
 * @param creator The address of the campaign creator
 * @param campaignId The ID of the campaign for which the target amount was changed
 * @param reason The reason for changing the target amount
 */
event TargetAmountChanged(address indexed creator, uint256 indexed campaignId, string reason);

/**
 * @title CryptoFundMe
 * @dev A contract for crowdfunding campaigns
 */
contract CryptoFundMe {
    using SafeERC20 for IERC20;

    struct Donation {
        address donator;
        uint256 donationAmount;
    }

    struct Campaign {
        address creator;
        address acceptedToken;
        uint256 targetAmount;
        uint256 deadline;
        uint256 amountCollected;
        string title;
        string description;
        string image;
    }

    mapping(uint256 campaignId => Campaign) public campaigns;
    mapping(uint256 campaignId => Donation[]) public donations;

    uint256 public numberOfCampaigns = 0;
    // Represents 0.1 ETH or 10^17 WEI
    uint256 public changeFee = 100_000_000_000_000_000;

    // Represents a 5% fee on donations
    UD60x18 public immutable DONATION_PERCENTAGE_FEE = ud(0.05e18);

    address public constant ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address owner;
    address payable feeTo;

    /**
     * @dev Modifier to check if the campaign is active
     * @param _id The ID of the campaign
     */
    modifier campaignIsActive(uint256 _id) {
        require(campaigns[_id].deadline > block.timestamp, "The campaign has ended");
        require(campaigns[_id].targetAmount > campaigns[_id].amountCollected, "The campaign has reached it's goal");

        _;
    }

    /**
     * @dev Modifier to check if the sender is the creator of the campaign
     * @param _id The ID of the campaign
     */
    modifier onlyCreator(uint256 _id) {
        require(campaigns[_id].creator == msg.sender, "Only campaign creator can execute this action");

        _;
    }

    /**
     * @dev Constructor to set the fee recipient
     * @param _feeTo The address to receive the fee
     */
    constructor(address _feeTo) {
        owner = msg.sender;
        feeTo = payable(_feeTo);
    }

    /**
     * @dev This function should be called for campaigns that want to accept ETH donations
     * @param _title The title of the campaign
     * @param _description The description of the campaign
     * @param _targetAmount The target amount to be raised
     * @param _deadline The deadline for the campaign
     * @param _image The image for the campaign
     * @return campaignId The ID of the newly created campaign
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _deadline,
        string memory _image
    ) external returns (uint256 campaignId) {
        campaignId = createCampaign(ETHER_ADDRESS, _title, _description, _targetAmount, _deadline, _image);
    }

    /**
     * @dev This function should be called for campaigns that want to accept ERC20 tokens
     * @param _acceptedToken The token that the campaign accepts for donations
     * @param _title The title of the campaign
     * @param _description The description of the campaign
     * @param _targetAmount The target amount to be raised
     * @param _deadline The deadline for the campaign
     * @param _image The image for the campaign
     * @return campaignId The ID of the newly created campaign
     */
    function createCampaign(
        address _acceptedToken,
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _deadline,
        string memory _image
    ) public returns (uint256 campaignId) {
        require(_deadline > block.timestamp, "The deadline should be a date in the future");
        require(_targetAmount > 0, "The target amount should be greater than 0");

        Campaign memory campaign = Campaign({
            creator: msg.sender,
            acceptedToken: _acceptedToken,
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            deadline: _deadline,
            amountCollected: 0,
            image: _image
        });
        campaigns[numberOfCampaigns] = campaign;

        emit CampaignCreated(campaign.creator, numberOfCampaigns);

        unchecked {
            return numberOfCampaigns++;
        }
    }

    /**
     * @dev Function to donate Ether to a campaign
     * @param _id The ID of the campaign to donate to
     * @return donationId The ID of the donation
     */
    function donateEtherToCampaign(uint256 _id) external payable campaignIsActive(_id) returns (uint256 donationId) {
        require(msg.value > 0, "No Ether sent for donation");

        UD60x18 donationAmount = ud(msg.value);
        Campaign storage campaign = campaigns[_id];
        UD60x18 feeAmount = calculateFee(donationAmount);
        uint256 netDonationAmount = unwrap(donationAmount.sub(feeAmount));

        donations[_id].push(Donation({ donator: msg.sender, donationAmount: netDonationAmount }));

        campaign.amountCollected = campaign.amountCollected + netDonationAmount;
        (bool feeSent,) = feeTo.call{ value: unwrap(feeAmount) }("");

        require(feeSent, "Failed to send fee");

        (bool donationSent,) = payable(campaign.creator).call{ value: netDonationAmount }("");

        require(donationSent, "Failed to send donation to campaign creator");

        emit Donated(msg.sender, _id, netDonationAmount);

        return donations[_id].length - 1;
    }

    /**
     * @dev Function to donate ERC20 tokens to a campaign
     * @param _id The ID of the campaign to donate to
     * @param _token The address of the token being donated
     * @param _amount The amount to donate
     * @return donationId The ID of the donation
     */
    function donateERC20ToCampaign(uint256 _id, IERC20 _token, uint256 _amount, bool coverFee)
        external
        campaignIsActive(_id)
        returns (uint256 donationId)
    {
        require(
            campaigns[_id].acceptedToken == address(_token), "This campaign does not accept donations of this token"
        );

        UD60x18 donationAmount = ud(_amount);
        UD60x18 feeAmount = calculateFee(donationAmount);
        uint256 netDonationAmount = coverFee ? unwrap(donationAmount) : unwrap(donationAmount.sub(feeAmount));
        Campaign storage campaign = campaigns[_id];

        donations[_id].push(Donation({ donator: msg.sender, donationAmount: netDonationAmount }));

        campaign.amountCollected = campaign.amountCollected + netDonationAmount;

        _token.safeTransferFrom(msg.sender, feeTo, unwrap(feeAmount));
        _token.safeTransferFrom(msg.sender, campaign.creator, netDonationAmount);

        emit Donated(msg.sender, _id, netDonationAmount);

        return donations[_id].length - 1;
    }

    /**
     * @dev Function to get the donators of a campaign
     * @param _id The ID of the campaign
     * @return Array of Donations containging the addresses of the donators and the amount that each address donated
     */
    function getCampaignDonations(uint256 _id) external view returns (Donation[] memory) {
        return donations[_id];
    }

    /**
     * @dev Function to get all campaigns
     * @return allCampaigns An array of all campaigns
     */
    function getCampaigns() external view returns (Campaign[] memory allCampaigns) {
        allCampaigns = new Campaign[](numberOfCampaigns);

        for (uint256 i = 0; i < numberOfCampaigns; ++i) {
            Campaign memory campaign = campaigns[i];
            allCampaigns[i] = campaign;
        }
    }

    /**
     * @dev Function to change the deadline of a campaign
     * @param _id The ID of the campaign
     * @param _newDeadline The new deadline for the campaign
     * @param _reason The reason for changing the deadline
     */
    function changeDeadline(uint256 _id, uint256 _newDeadline, string memory _reason)
        external
        payable
        campaignIsActive(_id)
        onlyCreator(_id)
    {
        require(msg.value == changeFee, "Incorrect change fee amount sent");

        (bool sent,) = feeTo.call{ value: msg.value }("");

        require(sent, "Failed to send fee");

        campaigns[_id].deadline = _newDeadline;

        emit DeadlineChanged(msg.sender, _id, _reason);
    }

    /**
     * @dev Function to change the target amount of a campaign
     * @param _id The ID of the campaign
     * @param _newTargetAmount The new target amount for the campaign
     * @param _reason The reason for changing the target amount
     */
    function changeTargetAmount(uint256 _id, uint256 _newTargetAmount, string memory _reason)
        external
        payable
        campaignIsActive(_id)
        onlyCreator(_id)
    {
        require(msg.value == changeFee, "Incorrect change fee amount sent");

        (bool sent,) = feeTo.call{ value: msg.value }("");

        require(sent, "Failed to send fee");

        campaigns[_id].targetAmount = _newTargetAmount;

        emit TargetAmountChanged(msg.sender, _id, _reason);
    }

    /**
     * @dev Function to set the change fee
     * @param _changeFee The new change fee
     */
    function setChangeFee(uint256 _changeFee) external {
        require(owner == msg.sender, "Only owner can set the fee to address");

        changeFee = _changeFee;
    }

    /**
     * @dev Function to set the fee recipient
     * @param _feeTo The new fee recipient
     */
    function setFeeTo(address _feeTo) external {
        require(owner == msg.sender, "Only owner can set the fee to address");

        feeTo = payable(_feeTo);
    }

    /**
     * @dev Function to calculate the fee for a donation
     * @param donationAmount The amount of the donation
     * @return feeAmount The fee for the donation
     */
    function calculateFee(UD60x18 donationAmount) public view returns (UD60x18 feeAmount) {
        return donationAmount.mul(DONATION_PERCENTAGE_FEE);
    }
}
