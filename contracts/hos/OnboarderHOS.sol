// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import "@daohaus/baal-contracts/contracts/interfaces/IBaalToken.sol";
import "@daohaus/baal-contracts/contracts/interfaces/IBaalSummoner.sol";

// TODO: use on upcoming release
// import "@daohaus/baal-contracts/contracts/interfaces/IBaalAndVaultSummoner.sol";

import "./HOSBase.sol";

import "../interfaces/IBaalFixedToken.sol";

import "hardhat/console.sol";

contract OnboarderShamanSummoner is HOSBase {
    function initialize(address _baalSummoner, address _moduleProxyFactory) public override {
        // standard baalSummoner
        super.initialize(_baalSummoner, _moduleProxyFactory);
        require(_baalSummoner != address(0), "zero address");
        emit SetSummoner(_baalSummoner);
    }

    /**
     * @dev summon a new baal contract with a newly created set of loot/shares tokens
     * uses base summoner to deploy baal, vault is not created and set to zero.
     * @param postInitActions actions ran in baal setup
     * @param lootToken address
     * @param sharesToken address
     * @param saltNonce unique nonce for baal summon
     * @return baal address
     * @return vault address
     */
    function summon(
        bytes[] memory postInitActions,
        address lootToken,
        address sharesToken,
        uint256 saltNonce
    ) internal override returns (address baal, address vault) {
        vault = address(0);
        baal = baalSummoner.summonBaalFromReferrer(
            abi.encode(
                IBaalFixedToken(sharesToken).name(),
                IBaalFixedToken(sharesToken).symbol(),
                address(0), // safe (0 addr creates a new one)
                address(0), // forwarder (0 addr disables feature)
                lootToken,
                sharesToken
            ),
            postInitActions,
            saltNonce, // salt nonce
            bytes32(bytes("DHOnboarderShamanSummoner")) // referrer
        );
    }

    /**
     * @dev internal function to set up the onboarder shaman with last three values in init params
     * @param shaman address
     * @param baal address
     * @param vault address
     * @param initializationShamanParams [template, [name, symbol, [tos], [amounts]]]
     *
     */
    function setUpShaman(
        address shaman,
        address baal,
        address vault,
        bytes memory initializationShamanParams,
        uint256 index
    ) internal {
        console.log("hos: shaman", shaman);
        console.log("hos: index", index);
        (, , bytes[] memory initShamanDeployParams) = abi.decode(
            initializationShamanParams,
            (address, uint256, bytes[])
        );
        IShaman(shaman).setup(baal, vault, initShamanDeployParams[index]);
    }

    /**
     * @dev deploys a new token (loot or shares) using a template and mints to summoners
     * @param initializationParams [template, [name, symbol, [tos], [amounts]]]
     * @return token address
     *
     */
    function deployToken(bytes calldata initializationParams) internal override returns (address token) {
        (address template, bytes memory initParams) = abi.decode(initializationParams, (address, bytes));

        (string memory name, string memory symbol, address[] memory tos, uint256[] memory amounts) = abi.decode(
            initParams,
            (string, string, address[], uint256[])
        );

        // ERC1967 could be upgradable
        token = address(
            new ERC1967Proxy(template, abi.encodeWithSelector(IBaalToken(template).setUp.selector, name, symbol))
        );

        for (uint256 i = 0; i < tos.length; i++) {
            IBaalToken(token).mint(tos[i], amounts[i]);
        }

        emit DeployBaalToken(token);
    }

    function deployShamans(
        bytes[] memory postInitializationActions,
        bytes memory initializationShamanParams,
        bytes32 saltNonce
    ) internal override returns (bytes[] memory actions, address[] memory shamanAddresses) {
        (actions, shamanAddresses) = super.deployMultiShamans(postInitializationActions, initializationShamanParams);
    }

    /**
     * @dev setsup the already deployed onboarder shaman with init params
     * @param initializationShamanParams [shaman, nonce, [uint256 _expiry, uint256 _multiply, uint256 _minTribute, bool _isShares]]
     * @param lootToken address
     * @param sharesToken address
     * @param shamans address
     * @param baal address
     * @param vault address or zero address if not used
     */
    function postDeployShamanActions(
        bytes calldata initializationShamanParams,
        address lootToken,
        address sharesToken,
        address[] memory shamans,
        address baal,
        address vault
    ) internal override {
        // init shaman here
        // shaman setup with dao address, vault address and initShamanParams
        for (uint256 i = 0; i < shamans.length; i++) {
            setUpShaman(shamans[i], baal, vault, initializationShamanParams, i);
        }

        super.postDeployShamanActions(initializationShamanParams, lootToken, sharesToken, shamans, baal, vault);
    }
}
