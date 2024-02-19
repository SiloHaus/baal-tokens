// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import "../../interfaces/IBaalGovToken.sol";

interface IPoster {
    function post(string memory content, string memory tag) external;
}

contract LootThreshDUCE is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IBaal _baal;
    IPoster _poster;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address baal) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        _baal = IBaal(baal);
        _poster = IPoster(0x000000000000cd17345801aa8147b8D3950260FF);
        transferOwnership(initialOwner);
    }

    function comment(string memory content) public {
        IBaalGovToken lootToken = IBaalGovToken(_baal.lootToken());
        uint256 threshold = _baal.sponsorThreshold();
        require(lootToken.balanceOf(msg.sender) >= threshold, "LootThreshDUCE: insufficient loot");
        _poster.post(content, "daohaus.shaman.database");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
