// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
        address owner;
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

    address constant ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @dev Emitted when a new campaign is created
     * @param owner The address of the campaign creator
     * @param campaignId The ID of the newly created campaign
     */
    event CampaignCreated(address indexed owner, uint256 indexed campaignId);

    /**
     * @dev Emitted when a donation is made to a campaign
     * @param donator The address of the donator
     * @param campaignId The ID of the campaign to which the donation was made
     * @param amountDonated The amount of the donation
     */
    event Donated(address indexed donator, uint256 indexed campaignId, uint256 amountDonated);

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
        require(_deadline > block.timestamp, "The deadline should be a date in the future.");
        require(_targetAmount > 0, "The target amount should be greater than 0.");

        Campaign memory campaign = Campaign({
            owner: msg.sender,
            acceptedToken: _acceptedToken,
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            deadline: _deadline,
            amountCollected: 0,
            image: _image
        });
        campaigns[numberOfCampaigns] = campaign;

        emit CampaignCreated(campaign.owner, numberOfCampaigns);

        unchecked {
            return numberOfCampaigns++;
        }
    }

    /**
     * @param _id The ID of the campaign to donate to
     */
    function donateEtherToCampaign(uint256 _id) external payable {
        require(campaigns[_id].acceptedToken == ETHER_ADDRESS, "This campaign does not accept Ether donations.");
        require(campaigns[_id].deadline > block.timestamp, "The campign has ended.");
        require(campaigns[_id].targetAmount > campaigns[_id].amountCollected, "The campign has reached it's goal.");

        uint256 amount = msg.value;
        Campaign storage campaign = campaigns[_id];

        donations[_id].push(Donation({ donator: msg.sender, donationAmount: amount }));

        campaign.amountCollected = campaign.amountCollected + amount;
        (bool sent,) = payable(campaign.owner).call{ value: amount }("");

        require(sent, "Failed to send donation to campaign owner");

        emit Donated(msg.sender, _id, amount);
    }

    /**
     * @param _id The ID of the campaign to donate to
     * @param _token The address of the token being donated
     * @param _amount The amount to donate
     */
    function donateERC20ToCampaign(uint256 _id, IERC20 _token, uint256 _amount) external {
        require(campaigns[_id].acceptedToken == address(_token), "This campaign does not accept donations of this token.");
        require(campaigns[_id].deadline > block.timestamp, "The campign has ended.");
        require(campaigns[_id].targetAmount > campaigns[_id].amountCollected, "The campign has reached it's goal.");

        Campaign storage campaign = campaigns[_id];

        donations[_id].push(Donation({ donator: msg.sender, donationAmount: _amount }));

        campaign.amountCollected = campaign.amountCollected + _amount;

        _token.safeTransferFrom(msg.sender, campaign.owner, _amount);

        emit Donated(msg.sender, _id, _amount);
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
}
