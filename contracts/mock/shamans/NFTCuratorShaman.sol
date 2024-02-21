// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";

interface IPoster {
    function post(string memory content, string memory tag) external;
}

contract NFTCuratorShaman is ERC721Upgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    string public constant shamanName = "NFTCuratorShamanV0.2";
    uint256 private _nextTokenId;
    string private _imageUri;
    string private _animationUri;
    string private _externalUri;
    IPoster public _poster;
    IBaal public _baal;
    uint256 public _price; // 420000000000000;
    uint256 public _authorFee;
    uint256 public _creatorShares;
    uint256 public _collectorLoot;

    mapping(bytes32 hash => uint256 tokenId) public posts;
    mapping(uint256 tokenId => bytes32 hash) public chashes;
    mapping(uint256 tokenId => uint256 parentId) public mints;

    mapping(uint256 parentId => uint256[] childIds) public childs;

    struct ChildData {
        uint256 tokenId;
        address owner;
    }

    function setup(
        address _moloch, // DAO address
        address _vault, // recipient vault
        bytes memory _initParams
    ) external initializer {
        (
            string memory name,
            string memory symbol,
            uint256 creatorShares,
            uint256 collectorLoot,
            uint256 price,
            uint256 authorFee
        ) = abi.decode(_initParams, (string, string, uint256, uint256, uint256, uint256));
        _baal = IBaal(_moloch);
        _price = price;
        _authorFee = authorFee;
        _creatorShares = creatorShares;
        _collectorLoot = collectorLoot;
        _poster = IPoster(0x000000000000cd17345801aa8147b8D3950260FF);
        _imageUri = "";
        _animationUri = "";
        _externalUri = "";
        _nextTokenId = 1;
        __Ownable_init();
        __ERC721Enumerable_init();
        __ERC721_init(name, symbol);
        transferOwnership(_baal.target());
    }

    function setImageUri(string memory uri) public onlyOwner {
        _imageUri = uri;
    }

    function setAnimationUri(string memory uri) public onlyOwner {
        _animationUri = uri;
    }

    function setExternalUri(string memory uri) public onlyOwner {
        _externalUri = uri;
    }

    function setPrice(uint256 price) public onlyOwner {
        _price = price;
    }

    function setBaal(address baal) public onlyOwner {
        _baal = IBaal(baal);
    }

    function setAuthorFee(uint256 authorFee) public onlyOwner {
        _authorFee = authorFee;
    }

    function setCollectorLoot(uint256 collectorLoot) public onlyOwner {
        _collectorLoot = collectorLoot;
    }

    function setCreatorShares(uint256 creatorShares) public onlyOwner {
        _creatorShares = creatorShares;
    }

    function getAllChilds(uint256 parentId) public view returns (ChildData[] memory) {
        ChildData[] memory childList = new ChildData[](childs[parentId].length);
        for (uint256 i = 0; i < childs[parentId].length; i++) {
            uint256 childId = childs[parentId][i];
            childList[i] = ChildData(childId, ownerOf(childId));
        }
        return childList;
    }

    function post(address to, bytes32 postId, string memory content) public onlyOwner {
        // only though proposal
        uint256 tokenId = _nextTokenId++;
        posts[postId] = tokenId;
        chashes[tokenId] = postId;
        _safeMint(to, tokenId);
        _poster.post(content, "daohaus.member.database");

        _mintTokens(to, _creatorShares, true);
    }

    function collect(bytes32 postId) public payable {
        require(msg.value == _price, "not enough to mint");
        require(posts[postId] != 0, "not a valid post");
        uint256 targetTokenId = posts[postId];
        uint256 authorFee = msg.value / _authorFee; // 5 = 20%
        address owner = ownerOf(targetTokenId);
        (bool feeSuccess, ) = owner.call{ value: authorFee }(""); /*Send ETH to author*/
        require(feeSuccess, "could not send fee to author");
        (bool success, ) = IBaal(_baal).target().call{ value: msg.value - authorFee }(""); /*Send ETH to dao*/
        require(success, "could not send to DAO");

        _mintTokens(owner, _collectorLoot, false);
        _mintTokens(msg.sender, _collectorLoot, false);

        uint256 tokenId = _nextTokenId++;
        mints[tokenId] = targetTokenId;
        childs[targetTokenId].push(tokenId);
        _safeMint(msg.sender, tokenId);
    }

    function _mintTokens(address to, uint256 amount, bool isShares) private {
        address[] memory receivers = new address[](1);
        receivers[0] = to;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        if (isShares) {
            IBaal(_baal).mintShares(receivers, amounts);
        } else {
            IBaal(_baal).mintLoot(receivers, amounts);
        }
    }

    /**
     * Constructs the tokenURI, separated out from the public function as its a big function.
     * Generates the json data URI
     * param: _tokenId the tokenId
     */
    function _constructTokenURI(uint256 tokenId) internal view returns (string memory) {
        string memory _nftName = string(abi.encodePacked(name()));
        string memory _image = string(abi.encodePacked("ipfs://", _imageUri));
        string memory _externalUrl = string(abi.encodePacked("ipfs://", _externalUri));
        string memory _animation = string(
            abi.encodePacked(
                "ipfs://",
                _animationUri,
                "?tokenId=",
                Strings.toString(tokenId),
                // "&chash=",
                // string(abi.encodePacked(chashes[tokenId])),
                "&parent=",
                Strings.toString(mints[tokenId])
            )
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                _nftName,
                                '", "image":"',
                                _image,
                                '", "external_url":"',
                                _externalUrl,
                                '", "animation_url":"',
                                _animation,
                                '", "description": DIN "',
                                _nftName,
                                '", ',
                                '"attributes": [{"trait_type": "base", "value": "post"}]}'
                            )
                        )
                    )
                )
            );
    }

    /* Returns the json data associated with this token ID
     * param _tokenId the token ID
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert("Non existent token");
        }
        return string(_constructTokenURI(tokenId));
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
