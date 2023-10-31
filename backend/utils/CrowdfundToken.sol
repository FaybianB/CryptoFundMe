// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrowdfundToken is ERC20("CrowdfundToken", "CT") {
    constructor() {
        _mint(msg.sender, type(uint256).max);
    }
}