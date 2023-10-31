// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

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
    uint256 public CHANGE_FEE = 100_000_000_000_000_000;

    // Represents a 5% fee on donations
    UD60x18 public DONATION_PERCENTAGE_FEE = ud(0.05e18);

    address public constant ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address owner;
    address payable feeTo;

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

    event DeadlineCanged(address indexed creator, uint256 indexed campaignId, string reason);

    event TargetAmountCanged(address indexed creator, uint256 indexed campaignId, string reason);

    modifier campaignIsActive(uint256 _id) {
        require(campaigns[_id].deadline > block.timestamp, "The campign has ended");
        require(campaigns[_id].targetAmount > campaigns[_id].amountCollected, "The campign has reached it's goal");

        _;
    }

    modifier onlyCreator(uint256 _id) {
        require(campaigns[_id].creator == msg.sender, "Only campaign creator can execute this action");

        _;
    }

    constructor() {
        owner = msg.sender;

        setFeeTo(owner);
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
     * @param _id The ID of the campaign to donate to
     */
    function donateEtherToCampaign(uint256 _id) external payable campaignIsActive(_id) {
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
    }

    /**
     * @param _id The ID of the campaign to donate to
     * @param _token The address of the token being donated
     * @param _amount The amount to donate
     */
    function donateERC20ToCampaign(uint256 _id, IERC20 _token, uint256 _amount) external campaignIsActive(_id) {
        require(
            campaigns[_id].acceptedToken == address(_token), "This campaign does not accept donations of this token"
        );

        UD60x18 donationAmount = ud(_amount);
        UD60x18 feeAmount = calculateFee(donationAmount);
        uint256 netDonationAmount = unwrap(donationAmount.sub(feeAmount));
        Campaign storage campaign = campaigns[_id];

        donations[_id].push(Donation({ donator: msg.sender, donationAmount: netDonationAmount }));

        campaign.amountCollected = campaign.amountCollected + netDonationAmount;

        _token.safeTransferFrom(msg.sender, feeTo, unwrap(feeAmount));
        _token.safeTransferFrom(msg.sender, campaign.creator, netDonationAmount);

        emit Donated(msg.sender, _id, netDonationAmount);
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
     * @return An array of all campaigns
     */
    function getCampaigns() external view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);

        for (uint256 i = 1; i < numberOfCampaigns; i++) {
            Campaign storage item = campaigns[i];
            allCampaigns[i] = item;
        }

        return allCampaigns;
    }

    function changeDeadline(uint256 _id, uint256 _newDeadline, string memory _reason)
        external
        payable
        campaignIsActive(_id)
        onlyCreator(_id)
    {
        require(msg.value == CHANGE_FEE, "Incorrect change fee amount sent");

        (bool sent,) = feeTo.call{ value: msg.value }("");

        require(sent, "Failed to send fee.");

        campaigns[_id].deadline = _newDeadline;

        emit DeadlineCanged(msg.sender, _id, _reason);
    }

    function changeTargetAmount(uint256 _id, uint256 _newTargetAmount, string memory _reason)
        external
        payable
        campaignIsActive(_id)
        onlyCreator(_id)
    {
        require(msg.value == CHANGE_FEE, "Incorrect change fee amount sent");

        (bool sent,) = feeTo.call{ value: msg.value }("");

        require(sent, "Failed to send fee.");

        campaigns[_id].targetAmount = _newTargetAmount;

        emit TargetAmountCanged(msg.sender, _id, _reason);
    }

    function setFeeTo(address _feeTo) public {
        require(owner == msg.sender, "Only owner can set the fee to address");

        feeTo = payable(_feeTo);
    }

    function calculateFee(UD60x18 donationAmount) public view returns (UD60x18 feeAmount) {
        feeAmount = donationAmount.mul(DONATION_PERCENTAGE_FEE);
    }
}
