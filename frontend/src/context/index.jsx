import React, { useContext, createContext } from 'react';
import { useAddress, useContract, useMetamask, useContractWrite } from '@thirdweb-dev/react';
import { ethers } from 'ethers';
import { daysLeft } from '../utils';

const StateContext = createContext();

export const StateContextProvider = ({ children }) => {
    const { contract } = useContract('0xcB12466e687a29DAF18926f35042384fdB81Da35');
    const { mutateAsync: createCampaign } = useContractWrite(contract, 'createCampaign');
    const address = useAddress();
    const connect = useMetamask();
    const etherAddress = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const publishCampaign = async (form) => {
        try {
            const data = await createCampaign({
                args: [form.acceptedToken ? form.acceptedToken : etherAddress, form.title, form.description, form.targetAmount, (new Date(form.deadline).getTime()) / 1000, form.image]
            });

            console.log("contract call success", data);
        } catch (error) {
            console.log("contract call failure", error);
        }
    }

    const getCampaigns = async (user) => {
        const campaigns = await contract.call('getCampaigns');
        const parsedCampaigns = campaigns.map((campaign, i) => ({
            creator: campaign.creator,
            title: campaign.title,
            description: campaign.description,
            targetAmount: ethers.utils.formatEther(campaign.targetAmount.toString()),
            deadline: campaign.deadline.toNumber(),
            amountCollected: ethers.utils.formatEther(campaign.amountCollected.toString()),
            image: campaign.image,
            acceptedToken: campaign.acceptedToken,
            campaignId: i
        }));
        let activeCampaigns = parsedCampaigns;

        if (!user) {
            activeCampaigns = parsedCampaigns.filter((campaign) => campaign.creator !== zeroAddress && daysLeft(campaign.deadline) > 0 && campaign.targetAmount > campaign.amountCollected);
        }

        activeCampaigns.sort((a, b) => a.deadline - b.deadline);

        return activeCampaigns;
    }

    const getUserCampaigns = async () => {
        const allCampaigns = await getCampaigns(true);
        const filteredCampaigns = allCampaigns.filter((campaign) => campaign.creator === address);

        return filteredCampaigns;
    }

    const donateERC20 = async (campaignId, token, amount, coverFee) => {
        const data = await contract.call('donateERC20ToCampaign', [campaignId, token, amount, coverFee]);

        return data;
    }


    const donateEther = async (campaignId, amount) => {
        const data = await contract.call('donateEtherToCampaign', [campaignId], { value: amount });

        return data;
    }

    const getDonations = async (campaignId) => {
        const donations = await contract.call('getCampaignDonations', [campaignId]);

        return donations;
    }

    const getTokenSymbol = async (tokenAddress) => {
        const { contract } = useContract(tokenAddress);

        if (contract) {
            const tokenSymbol = await contract.call('symbol');

            return tokenSymbol;
        } else {
            return '';
        }
    }

    return (
        <StateContext.Provider value={{ address, contract, connect, createCampaign: publishCampaign, getCampaigns, getUserCampaigns, donateERC20, donateEther, getDonations, getTokenSymbol }}>
            {children}
        </StateContext.Provider>
    )
}

export const useStateContext = () => useContext(StateContext);