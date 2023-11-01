// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { CryptoFundMe } from "../../src/CryptoFundMe.sol";

contract CryptoFundMeHarness is CryptoFundMe(msg.sender) {
    function exposed_feeTo() external view returns (address) {
        return feeTo;
    }
}