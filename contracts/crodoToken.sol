// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract CrodoToken is ERC20, ERC20Pausable, ERC20Capped {
    string private _name = "CrodoToken";
    string private _symbol = "CROD";
    uint8 private _decimals = 18;
    address public distributionContractAddress;
    // 100 Million <---------|   |-----------------> 10^18
    uint256 constant TOTAL_CAP = 100000000 * 1 ether;

    constructor(address _distributionContract)
        ERC20Capped(TOTAL_CAP)
        ERC20(_name, _symbol)
    {
        distributionContractAddress = _distributionContract;
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        // require(
        //     account == distributionContractAddress,
        //     "Only distribution contract can mint Crodo tokens"
        // );
        ERC20Capped._mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        ERC20._beforeTokenTransfer(from, to, amount);
    }
}
