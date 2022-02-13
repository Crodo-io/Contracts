// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    string private _name = "TestToken";
    string private _symbol = "TK";
    uint8 private _decimals;

    constructor(uint8 num_decimals, address mintAddress, uint256 mintAmount)
        ERC20(_name, _symbol)
    {
        _decimals = num_decimals;
        _mint(mintAddress, mintAmount);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
