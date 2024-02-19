// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@gnosis.pm/zodiac/contracts/factory/ModuleProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import "@daohaus/baal-contracts/contracts/interfaces/IBaalSummoner.sol";
import "@daohaus/baal-contracts/contracts/interfaces/IBaalToken.sol";

// TODO: use on upcoming release
// import "@daohaus/baal-contracts/contracts/interfaces/IBaalAndVaultSummoner.sol";

import "../interfaces/IShaman.sol";
import "../interfaces/IBaalFixedToken.sol";
import "../interfaces/IBaalAndVaultSummoner.sol";

import "hardhat/console.sol";

contract HOSBase is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IBaalSummoner public baalSummoner;
    address public moduleProxyFactory;

    event SetSummoner(address summoner);

    event DeployBaalToken(address tokenAddress);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _baalSummoner, address _moduleProxyFactory) public virtual initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        baalSummoner = IBaalSummoner(_baalSummoner);
        moduleProxyFactory = _moduleProxyFactory;
    }

    function calculateBaalAddress(uint256 _saltNonce) public view returns (address) {
        bytes memory _initializer = abi.encodeWithSignature("avatar()");
        bytes32 _salt = keccak256(abi.encodePacked(keccak256(_initializer), _saltNonce));
        bytes memory bytecode = abi.encodePacked(
            hex"602d8060093d393df3363d3d373d3d3d363d73",
            baalSummoner.template(),
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        bytes32 predictedHash = keccak256(
            abi.encodePacked(bytes1(0xff), moduleProxyFactory, _salt, keccak256(bytecode))
        );

        return address(uint160(uint(predictedHash)));
    }

    /**
     * @dev Summon a new Baal contract with a new set of tokens, optional vault and shaman
     * @param initializationLootTokenParams The parameters for deploying the token
     * @param initializationShareTokenParams The parameters for deploying the token
     * @param initializationShamanParams  The parameters for deploying the shaman
     * @param postInitializationActions The actions to be performed after the initialization
     */
    function summonBaalFromReferrer(
        bytes calldata initializationLootTokenParams,
        bytes calldata initializationShareTokenParams,
        bytes calldata initializationShamanParams, // maybe break out baal init params and shaman init params
        bytes[] memory postInitializationActions,
        uint256 saltNonce
    ) external virtual returns (address) {
        address predictedBaalAddress = calculateBaalAddress(saltNonce);
        //
        address lootToken = deployLootToken(initializationLootTokenParams, predictedBaalAddress);

        address sharesToken = deploySharesToken(initializationShareTokenParams, predictedBaalAddress);

        (bytes[] memory amendedPostInitActions, address[] memory shamans) = deployShamans(
            postInitializationActions,
            initializationShamanParams,
            bytes32(saltNonce)
        );

        // summon baal with new tokens
        (address baal, address vault) = summon(amendedPostInitActions, lootToken, sharesToken, saltNonce);

        // console.log("baal >>", baal, predictedBaalAddress);
        // post deploy hooks
        postDeployShamanActions(initializationShamanParams, lootToken, sharesToken, shamans, baal, vault);

        return baal;
    }

    /**
     * @dev Summon a new Baal contract with a new set of tokens
     * @param postInitActions The actions to be performed after the initialization
     * @param lootToken The address of the loot token
     * @param sharesToken The address of the shares token
     * @param saltNounce The salt nonce for the summon
     */
    function summon(
        bytes[] memory postInitActions,
        address lootToken,
        address sharesToken,
        uint256 saltNounce
    ) internal virtual returns (address baal, address vault) {}

    /**
     * @dev postDeployShamanActions by default tokens are transfered to baal
     * @param initializationShamanParams The parameters for deploying the token
     * @param lootToken The address of the loot token
     * @param sharesToken The address of the shares token
     * @param shamans The address of the shaman
     * @param baal The address of the baal
     * @param vault The address of the vault
     */
    function postDeployShamanActions(
        bytes calldata initializationShamanParams,
        address lootToken,
        address sharesToken,
        address[] memory shamans,
        address baal,
        address vault
    ) internal virtual {}

    /**
     * @dev deployLootToken
     * @param initializationParams The parameters for deploying the token
     */
    function deployLootToken(
        bytes calldata initializationParams,
        address initialOwner
    ) internal virtual returns (address token) {
        token = deployToken(initializationParams);
        IBaalToken(token).transferOwnership(initialOwner);
    }

    /**
     * @dev deploySharesToken
     * @param initializationParams The parameters for deploying the token
     */
    function deploySharesToken(
        bytes calldata initializationParams,
        address initialOwner
    ) internal virtual returns (address token) {
        token = deployToken(initializationParams);
        IBaalToken(token).transferOwnership(initialOwner);
    }

    /**
     * @dev deployToken
     * @param initializationParams The parameters for deploying the token
     */
    function deployToken(bytes calldata initializationParams) internal virtual returns (address token) {
        (address template, bytes memory initDeployParams) = abi.decode(initializationParams, (address, bytes));

        (string memory name, string memory symbol) = abi.decode(initDeployParams, (string, string));

        // ERC1967 could be upgradable
        token = address(
            new ERC1967Proxy(template, abi.encodeWithSelector(IBaalToken(template).setUp.selector, name, symbol))
        );

        emit DeployBaalToken(token);
    }

    function deployShamans(
        bytes[] memory postInitializationActions,
        bytes memory initializationShamanParams,
        bytes32 saltNonce
    ) internal virtual returns (bytes[] memory, address[] memory shamanAddresses) {}

    function deployPredeterminedShaman(
        bytes[] memory postInitializationActions,
        bytes memory initializationShamanParams,
        bytes32 saltNonce
    ) internal virtual returns (bytes[] memory, address[] memory) {
        (address shamanTemplate, uint256 shamanPermission, ) = abi.decode(
            initializationShamanParams,
            (address, uint256, bytes[])
        );

        uint256 actionsLength = postInitializationActions.length;
        // amend postInitializationActions to include setShamans
        bytes[] memory amendedPostInitActions = new bytes[](actionsLength + 1);

        require(shamanTemplate != address(0), "HOS: shamanTemplates address is zero");
        // Clones because it should not need to be upgradable
        IShaman shaman = IShaman(payable(Clones.cloneDeterministic(shamanTemplate, saltNonce)));
        address[] memory shamanAddresses = new address[](1);
        shamanAddresses[0] = address(shaman);
        uint256[] memory shamanPermissions = new uint256[](1);
        shamanPermissions[0] = shamanPermission;

        // copy over the rest of the actions
        for (uint256 i = 0; i < actionsLength; i++) {
            amendedPostInitActions[i] = postInitializationActions[i];
        }
        amendedPostInitActions[actionsLength] = abi.encodeWithSignature(
            "setShamans(address[],uint256[])",
            shamanAddresses,
            shamanPermissions
        );

        return (amendedPostInitActions, shamanAddresses);
    }

    /**
     * @dev deployShamans
     * the setShaman action is added to the postInitializationActions
     * shaman is not fully setup here, only the address is set
     * @param postInitializationActions The actions to be performed after the initialization
     * @param initializationShamanParams The parameters for deploying the shaman (address template, uint256 permissions, ) third peram is for poste deploy init
     *
     */
    function deployMultiShamans(
        bytes[] memory postInitializationActions,
        bytes memory initializationShamanParams
    ) internal returns (bytes[] memory, address[] memory) {
        // summon shaman

        (address[] memory shamanTemplates, uint256[] memory shamanPermissions, ) = abi.decode(
            initializationShamanParams,
            (address[], uint256[], bytes[])
        );
        require(shamanTemplates.length == shamanPermissions.length, "HOS: shamanTemplates length mismatch");

        uint256 actionsLength = postInitializationActions.length;
        // amend postInitializationActions to include setShamans
        bytes[] memory amendedPostInitActions = new bytes[](actionsLength + 1);

        // create arrays to hold shaman template address and permissions
        address[] memory shamanAddresses = new address[](shamanTemplates.length);
        uint256[] memory permissions = new uint256[](shamanTemplates.length);

        for (uint256 i = 0; i < shamanTemplates.length; i++) {
            require(shamanTemplates[i] != address(0), "HOS: shamanTemplates address is zero");
            // Clones because it should not need to be upgradable
            IShaman shaman = IShaman(payable(Clones.clone(shamanTemplates[i])));
            shamanAddresses[i] = address(shaman);
            permissions[i] = shamanPermissions[i];
        }

        // copy over the rest of the actions
        for (uint256 i = 0; i < actionsLength; i++) {
            amendedPostInitActions[i] = postInitializationActions[i];
        }
        amendedPostInitActions[actionsLength] = abi.encodeWithSignature(
            "setShamans(address[],uint256[])",
            shamanAddresses,
            permissions
        );

        return (amendedPostInitActions, shamanAddresses);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
