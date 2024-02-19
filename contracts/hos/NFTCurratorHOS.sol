// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import "@daohaus/baal-contracts/contracts/interfaces/IBaalToken.sol";

// TODO: use on upcoming release
// import "@daohaus/baal-contracts/contracts/interfaces/IBaalAndVaultSummoner.sol";

import "./HOSBase.sol";

import "../interfaces/IBaalGovToken.sol";

// import "hardhat/console.sol";

contract NFTCurratorShamanSummoner is HOSBase {
    function initialize(address _baalSummoner, address _moduleProxyFactory) public override {
        // standard baalSummoner
        super.initialize(_baalSummoner, _moduleProxyFactory);
        require(_baalSummoner != address(0), "zero address");
        emit SetSummoner(_baalSummoner);
    }

    /**
     * @dev summon a new baal contract with a newly created set of loot/shares tokens
     * uses baal and vault summoner to deploy baal and side vault
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
                IBaalGovToken(sharesToken).name(),
                IBaalGovToken(sharesToken).symbol(),
                address(0), // safe (0 addr creates a new one)
                address(0), // forwarder (0 addr disables feature)
                lootToken,
                sharesToken
            ),
            postInitActions,
            saltNonce, // salt nonce
            bytes32(bytes("DHNFTCurratorShamanSummoner")) // referrer
        );
    }

    /**
     * @dev deploySharesToken
     * @param initializationParams The parameters for deploying the token
     */
    function deployLootToken(
        bytes calldata initializationParams,
        address initialOwner
    ) internal override returns (address token) {
        token = super.deployToken(initializationParams);
        IBaalGovToken(token).transferOwnership(initialOwner);
    }

    /**
     * @dev deploySharesToken
     * @param initializationParams The parameters for deploying the token
     */
    function deploySharesToken(
        bytes calldata initializationParams,
        address initialOwner
    ) internal override returns (address token) {
        token = super.deployToken(initializationParams);
        IBaalGovToken(token).transferOwnership(initialOwner);
    }

    /**
     * @dev setUpShaman
     * NFT6551ClaimShaman
     * init params (address _nftAddress, address _registry, address _tbaImp, uint256 _perNft, uint256 _sharesPerNft)
     * @param shaman The address of the shaman
     * @param baal The address of the baal
     * @param vault The address of the vault
     * @param initializationShamanParams The parameters for deploying the token
     * @param index The index of the shaman
     */
    function setUpShaman(
        address shaman,
        address baal,
        address vault,
        bytes memory initializationShamanParams,
        uint256 index
    ) internal {
        // TODO: mismatch length check, it is not checking the length of initializationShamanParams
        // against the length of shamans
        (, , bytes[] memory initShamanDeployParams) = abi.decode(
            initializationShamanParams,
            (address, uint256, bytes[])
        );
        IShaman(shaman).setup(baal, vault, initShamanDeployParams[index]);
    }

    function deployShamans(
        bytes[] memory postInitializationActions,
        bytes memory initializationShamanParams,
        bytes32 saltNonce
    ) internal override returns (bytes[] memory actions, address[] memory shamanAddresses) {
        (actions, shamanAddresses) = super.deployPredeterminedShaman(
            postInitializationActions,
            initializationShamanParams,
            saltNonce
        );
    }

    /**
     * @dev sets up the already deployed claim shaman with init params
     * shaman init params (address _nftAddress, address _registry, address _tbaImp, uint256 _perNft, uint256 _sharesPerNft)
     * @param initializationShamanParams shaman init params
     * @param lootToken address
     * @param sharesToken address
     * @param shamans IShamans
     * @param baal address
     * @param vault address
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
    }

    function predictDeterministicShamanAddress(
        address implementation,
        uint256 salt
    ) external view returns (address predicted) {
        return Clones.predictDeterministicAddress(implementation, bytes32(salt), address(this));
    }
}
