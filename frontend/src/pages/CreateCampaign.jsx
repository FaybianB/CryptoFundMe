import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ethers } from 'ethers';
import { money } from '../assets';
import { CustomButton, FormField, Loader } from '../components';
import { checkIfImage } from '../utils';
import { useStateContext } from '../context';

const CreateCampaign = () => {
  const navigate = useNavigate();
  const [isLoading, setIsLoading] = useState(false);
  const { createCampaign } = useStateContext();
  const [form, setForm] = useState({
    title: '',
    description: '',
    targetAmount: '',
    deadline: '',
    image: '',
    acceptedToken: ''
  });

  const handleFormFieldChange = (fieldName, e) => {
    setForm({ ...form, [fieldName]: e.target.value });
  }

  const handleSubmit = async (e) => {
    e.preventDefault();

    checkIfImage(form.image, async (exists) => {
      if (exists) {
        setIsLoading(true);

        try {
          let campaignId = await createCampaign({ ...form });

          if (typeof campaignId === 'number') {
            navigate('/');
          }
        } catch (error) {
          console.log(error);

          alert(error);
        }

        setIsLoading(false);
      } else {
        alert('Provide valid image URL');

        setForm({ ...form, image: '' });
      }
    });
  }

  return (
    <>
      {isLoading && <Loader />}
      <div className="bg-[#1c1c24] flex justify-center items-center flex-col rounded-[10px] sm:p-10 p-4">
        <div className="flex justify-center items-center p-[16px] sm:min-w-[380px] bg-[#3a3a43] rounded-[10px]">
          <h1 className='font-epilogue font-bold sm:text-[25px] text-[18px] leading-[38px] text-white'>
            Start a Campaign
          </h1>
        </div>

        <form onSubmit={handleSubmit} className="w-full mt-[65px] flex flex-col gap-[30px]">
          <div className="flex flex-wrap gap-[40px]">
            <FormField required={true} labelName="Campaign Title *" placeholder="Write a title" inputType="text" value={form.title} handleChange={(e) => handleFormFieldChange('title', e)} />
          </div>

          <FormField required={true} labelName="Story *" placeholder="Write your story" isTextArea value={form.description} handleChange={(e) => handleFormFieldChange('description', e)} />

          <div className="w-full flex justify-center items-center p-4 bg-[#8c6dfd] h-[120px] rounded-[10px]">
            <img src={money} alt="money" className="w-[40px] h-[40px] object-contain" />
            <h4 className="font-epilogue font-bold text-[25px] text-white ml-[20px]">You will get 100% of the raised amount</h4>
          </div>

          <div className="flex flex-wrap gap-[40px]">
            <FormField required={false} labelName="Accepted Token Address" placeholder="Leave blank for ETH" inputType="text" value={form.acceptedToken} handleChange={(e) => handleFormFieldChange('acceptedToken', e)} />
            <FormField required={true} labelName="Goal *" placeholder="Enter amount in smallest unit" inputType="text" value={form.targetAmount} handleChange={(e) => handleFormFieldChange('targetAmount', e)} />
          </div>

          <div className="flex flex-wrap gap-[40px]">
            <FormField required={true} labelName="End Date *" placeholder="End Date" inputType="date" value={form.deadline} handleChange={(e) => handleFormFieldChange('deadline', e)} />
            <FormField required={true} labelName="Campaign Image *" placeholder="Place image URL of your campaign" inputType="url" value={form.image} handleChange={(e) => handleFormFieldChange('image', e)} />
          </div>

          <div className="flex justify-center items-center mt-[40px]">
            <CustomButton disabled={isLoading} btnType="submit" title={isLoading ? 'Submiting...' : 'Submit new campaign'} styles={isLoading ? 'bg-[#3a3a43]' : 'bg-[#1dc071]'} />
          </div>
        </form>
      </div>
    </>
  )
}

export default CreateCampaign