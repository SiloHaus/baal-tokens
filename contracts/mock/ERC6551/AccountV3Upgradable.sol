// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./AccountV3.sol";

contract AccountV3Upgradable is AccountV3a, UUPSUpgradeable {
    constructor(
        address entryPoint_,
        address multicallForwarder,
        address erc6551Registry,
        address guardian
    ) AccountV3a(entryPoint_, multicallForwarder, erc6551Registry, guardian) {}

    function _authorizeUpgrade(address implementation) internal virtual override {
        if (!guardian.isTrustedImplementation(implementation)) revert InvalidImplementation();
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();
    }
}
