// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";

error AlreadyInitialMinted();
error InsufficientValue(uint256 cost, uint256 value);
error EtherTransferFailed(address recipient, uint256 amount);
error BurnAmountTooHigh(uint256 balance, uint256 amount);
error NotSupported();
error OnlyWholeTokens();

contract BondingLoot is
    ERC20SnapshotUpgradeable,
    ERC20PermitUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    bool public _initialMintingLocked;

    event Mint(address indexed account, uint256 amount, uint256 totalSupply);
    event Burn(address indexed account, uint256 amount, uint256 totalSupply);

    constructor() {
        _disableInitializers();
    }

    /// @notice Configure loot - called by Baal on summon
    /// @dev initializer should prevent this from being called again
    /// @param params setup params
    function setUp(bytes calldata params) external initializer {
        (string memory name_, string memory symbol_) = abi.decode(params, (string, string));

        require(bytes(name_).length != 0, "loot: name empty");
        require(bytes(symbol_).length != 0, "loot: symbol empty");

        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __Pausable_init();
        __ERC20Snapshot_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    modifier onlyOwnerOrGovernor() {
        require(
            _msgSender() == owner() || IBaal(owner()).isGovernor(_msgSender()),
            "!owner & !governor"
        ); /*check `shaman` is governor*/
        _;
    }

    /// @notice Allows baal to create a snapshot
    function snapshot() external onlyOwnerOrGovernor returns (uint256) {
        return _snapshot();
    }

    /// @notice get current SnapshotId
    function getCurrentSnapshotId() external view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    /// @notice Baal-only function to pause shares.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Baal-only function to pause shares.
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Baal-only function to mint loot. notsupported in fixed loot
    /// @param recipient Address to receive loot
    /// @param amount Amount to mint
    function mint(address recipient, uint256 amount) external view onlyOwner {
        // should revert
        revert NotSupported();
    }

    function mint(uint256 amount_) external payable {
        if (amount_ % (10 ** decimals()) != 0) {
            revert OnlyWholeTokens();
        }
        uint256 cost = mintCost(amount_);

        if (msg.value < cost) {
            revert InsufficientValue(cost, msg.value);
        }

        _mint(msg.sender, amount_);

        if (msg.value > cost) {
            (bool sent, ) = msg.sender.call{ value: msg.value - cost }("");
            if (!sent) {
                revert EtherTransferFailed(msg.sender, msg.value - cost);
            }
        }

        emit Mint(msg.sender, amount_, totalSupply());
    }

    function burn(address account, uint256 amount_) external onlyOwner {
        if (amount_ > balanceOf(account)) {
            revert BurnAmountTooHigh(balanceOf(account), amount_);
        }
        if (amount_ % (10 ** decimals()) != 0) {
            revert OnlyWholeTokens();
        }

        // Calculate refund before burn, to use the totalSupply before the burn
        uint256 proceeds = burnProceeds(amount_);

        _burn(account, amount_);

        // TODO: this should go to a DAO vault instead of the owner (dao contract)
        uint256 fee = daoFee(proceeds);
        (bool feeSent, ) = owner().call{ value: daoFee(fee) }("");
        if (!feeSent) {
            revert EtherTransferFailed(account, proceeds - fee);
        }

        (bool sent, ) = account.call{ value: proceeds }("");
        if (!sent) {
            revert EtherTransferFailed(account, proceeds);
        }

        emit Burn(account, amount_, totalSupply());
    }

    function mintCost(uint256 amount_) public view returns (uint256) {
        if (amount_ % (10 ** decimals()) != 0) {
            revert OnlyWholeTokens();
        }
        // The sum of the prices of all tokens already minted
        uint256 sumPricesCurrentTotalSupply = _sumOfPriceToNTokens(totalSupply());
        // The sum of the prices of all the tokens already minted + the tokens to be newly minted
        uint256 sumPricesNewTotalSupply = _sumOfPriceToNTokens(totalSupply() + amount_);

        return sumPricesNewTotalSupply - sumPricesCurrentTotalSupply;
    }

    function burnProceeds(uint256 amount_) public view returns (uint256) {
        if (amount_ % (10 ** decimals()) != 0) {
            revert OnlyWholeTokens();
        }
        // The sum of the prices of all the tokens already minted
        uint256 sumBeforeBurn = _sumOfPriceToNTokens(totalSupply());
        // The sum of the prices of all the tokens after burning amount_
        uint256 sumAfterBurn = _sumOfPriceToNTokens(totalSupply() - amount_);

        return sumBeforeBurn - sumAfterBurn;
    }

    function daoFee(uint256 amount_) public view returns (uint256) {
        return amount_ / 100;
    }

    // function (10 ** decimals()) public view override returns (uint8) {
    //     return 0;
    // }

    // The price of *all* tokens from number 1 to n.
    function _sumOfPriceToNTokens(uint256 n) internal view returns (uint256) {
        uint256 n_ = n / (10 ** decimals());
        return ((n_ * (n_ + 1) * (2 * n_ + 1)) / 6);
    }

    /// @notice function to mint initial loot.
    /// can oly be run once then minting is locked going forward
    /// first 2 amounts in the array are reserved for the vault and the claim shaman
    /// any furture distributions will be done after that offset
    /// @dev can only be called once
    /// @param vault Address to receive vault loot (zero index)
    /// @param claimShaman Address to receive claim shaman loot (one index)
    /// @param params setup params
    function initialMint(address vault, address claimShaman, bytes memory params) external onlyOwner {
        if (_initialMintingLocked) {
            revert AlreadyInitialMinted();
        }

        (, , address[] memory initialHolders, uint256[] memory initialAmounts) = abi.decode(
            params,
            (string, string, address[], uint256[])
        );

        _initialMintingLocked = true;
        if (initialAmounts.length > 1) {
            _mint(vault, initialAmounts[0]);
            _mint(claimShaman, initialAmounts[1]);
        }

        for (uint256 i = 0; i < initialHolders.length; i++) {
            _mint(initialHolders[i], initialAmounts[i + 2]);
        }
    }

    /// @notice Internal hook to restrict token transfers unless allowed by baal
    /// @dev Allows transfers if msg.sender is Baal which enables minting and burning
    /// @param from The address of the source account.
    /// @param to The address of the destination account.
    /// @param amount The number of `loot` tokens to transfer.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20SnapshotUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
        require(
            from == address(0) /*Minting allowed*/ ||
                (msg.sender == owner() && to == address(0)) /*Burning by Baal allowed*/ ||
                !paused(),
            "loot: !transferable"
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
