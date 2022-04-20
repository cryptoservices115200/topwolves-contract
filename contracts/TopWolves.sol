// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TopWolves is ERC721, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using SafeMath for uint16;
    using SafeMath for uint8;
    uint16 private _tokenId;

    address teamWalletAddress = 0xFCb31b17eaB846e337138eA8964B76A5f02E71e0;

    uint16 public secretFreeMintLimit = 100;
    uint16 public totalLimit = 1111;

    /**
     * Mint Step flag
     * 0:   freeMint (for giveaway and promotion),
     * 1:   preSale - 3 hours
     * 2:   publicSale,
     * 3:   paused
     * 4:   not started
     */
    uint8 public mintStep = 4;
    uint256 revealTime = 0;
    bytes32 private merkleRoot;
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint public mintPriceDiscount = 0.001 ether;  // 0.1
    uint public mintPrice = 0.0012 ether;         // 0.12

    string private realBaseURI = "https://gateway.pinata.cloud/ipfs/QmRiNsuRoYQmSAnvziBHSY4xHN43BHxgjvnoDxKyQQQ8Un/";
    string private virtualURI = "";

    uint8 private MAX_PER_MINT = 3;
    uint8 public MAX_PER_WALLET = 20;

    uint256 presaleTime = 3600 * 16;
    uint256 public presaleStartTime = block.timestamp;

    mapping (address => uint8) adressPresaleCountMap;     // Up to 1
    mapping (address => uint8) addressPublicSaleCountMap;       // Up to Unlimited

    modifier onlyAdmin() {
        require(hasRole(ADMIN, msg.sender), "not allowed");
        _;
    }

    constructor() ERC721("TopWolves", "TW") {
        for (uint16 i = 0; i < secretFreeMintLimit; i++) {
            _tokenId++;
            _safeMint(teamWalletAddress, _tokenId);
        }
        totalLimit -= secretFreeMintLimit;
        _grantRole(ADMIN, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    event Mint (address indexed _from,
                uint8 _mintStep,
                uint _tokenId,
                uint _mintPrice,
                uint8 _mintCount,
                uint8 _freeMintCount,
                uint8 _publicSaleCount);

    event Setting ( uint8 _mintStep,
                    uint256 _mintPrice,
                    uint256 _mintPriceDiscount,
                    uint16 _totalLimit,
                    uint8 _MAX_PER_MINT);


    function _baseURI() internal view override returns (string memory) {
        if(block.timestamp > revealTime) {
            return realBaseURI;
        }
        else {
            return virtualURI;
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        if(block.timestamp > revealTime) {
            return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId), ".json"));
        }
        else {
            return string(abi.encodePacked(_baseURI(), "symbol.json"));
        }
    }

    function _leaf(address account) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _verifyWhitelist(bytes32 leaf, bytes32[] memory _merkleProof) private view returns (bool){
		return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
	}

    function setPresaleStart() external onlyAdmin returns (uint256) {
        presaleStartTime = block.timestamp;
        mintStep = 1;
        return presaleStartTime;
    }

    function isWhiteListMember(address account, bytes32[] memory _proof) external view returns (bool) {
        return _verifyWhitelist(_leaf(account), _proof);
    }

    function mintPresale(uint8 _mintCount, bytes32[] memory _proof) external payable nonReentrant returns (uint256) {
        require(_verifyWhitelist(_leaf(msg.sender), _proof) == true);
        require(_mintCount > 0);
        require(msg.sender != address(0));
        require(mintStep == 1);
        require(block.timestamp > presaleStartTime + presaleTime || (block.timestamp <= presaleStartTime + presaleTime && _mintCount <= MAX_PER_MINT));
        require(msg.value == (mintPriceDiscount * _mintCount));
        require(adressPresaleCountMap[msg.sender] + _mintCount <= MAX_PER_WALLET);

        for (uint8 i = 0; i < _mintCount; i++) {
            _tokenId++;
            _safeMint(msg.sender, _tokenId);
        }

        adressPresaleCountMap[msg.sender] += _mintCount;
        totalLimit -= _mintCount;

        emit Mint(msg.sender,
                    mintStep,
                    _tokenId,
                    mintPrice,
                    _mintCount,
                    adressPresaleCountMap[msg.sender],
                    addressPublicSaleCountMap[msg.sender]);

        return _tokenId;
    }

    function mintPublic(uint8 _mintCount) external payable nonReentrant returns (uint256) {
        require(mintStep == 2 && _mintCount > 0, "Not Public Mint Step");
        require(msg.sender != address(0));
        require(msg.value == (mintPrice * _mintCount),"Incorrect the send price");
        require(_mintCount <= totalLimit);
        require(_mintCount <= MAX_PER_MINT);
        require(_mintCount + adressPresaleCountMap[msg.sender] + addressPublicSaleCountMap[msg.sender] <= MAX_PER_WALLET);

        for (uint8 i = 0; i < _mintCount; i++) {
            _tokenId++;
            _safeMint(msg.sender, _tokenId);
        }

        addressPublicSaleCountMap[msg.sender] += _mintCount;
        totalLimit -= _mintCount;

        emit Mint(msg.sender,
                    mintStep,
                    _tokenId,
                    mintPrice,
                    _mintCount,
                    adressPresaleCountMap[msg.sender],
                    addressPublicSaleCountMap[msg.sender]);

        return _tokenId;
    }

    function setMintStep(uint8 _mintStep) external onlyAdmin returns (uint8) {
        require(_mintStep >= 0 && _mintStep <= 4);
        mintStep = _mintStep;
        emit Setting(mintStep, mintPrice, mintPriceDiscount, totalLimit, MAX_PER_MINT);
        return mintStep;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external {
        require(
            hasRole(ADMIN, msg.sender) || hasRole(WITHDRAWER_ROLE, msg.sender),
            "not allowed"
        );
        require(address(this).balance != 0, "withdrawFunds: must have funds to withdraw");
        uint256 balance = address(this).balance;
        if (hasRole(WITHDRAWER_ROLE, msg.sender)) {
            payable(msg.sender).transfer(balance);
        } else {
            payable(teamWalletAddress).transfer(balance);
        }
    }

    function setRealBaseURI(string memory _realBaseURI) external onlyAdmin returns (string memory) {
        realBaseURI = _realBaseURI;
        return realBaseURI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyAdmin returns (bytes32) {
        merkleRoot = _merkleRoot;
        return merkleRoot;
    }

    function getTokenList(address account) external view returns (uint256[] memory) {
        require(account != address(0));

        uint256 count = balanceOf(account);
        uint256[] memory tokenIdList = new uint256[](count);

        if (count == 0)
            return tokenIdList;

        uint256 cnt = 0;
        for (uint256 i = 1; i < (_tokenId + 1); i++) {

            if (_exists(i) && (ownerOf(i) == account)) {
                tokenIdList[cnt++] = i;
            }

            if (cnt == count)
                break;
        }

        return tokenIdList;
    }

    function getSetting() external view returns (uint256[] memory) {
        uint256[] memory setting = new uint256[](5);
        setting[0] = mintStep;
        setting[1] = mintPrice;
        setting[2] = mintPriceDiscount;
        setting[3] = totalLimit;
        setting[4] = MAX_PER_MINT;
        return setting;
    }

    function getAccountStatus(address account) external view returns (uint8[] memory) {
        require(account != address(0));

        uint8[] memory status = new uint8[](2);

        if(balanceOf(account) == 0)
            return status;

        status[0] = adressPresaleCountMap[account];
        status[1] = addressPublicSaleCountMap[account];
        return status;
    }

    function grantRole(bytes32 _role, address _user) public override onlyAdmin {
        _grantRole(_role, _user);
    }

    function revokeRole(bytes32 _role, address _user)
    public
    override
    onlyAdmin
    {
        _revokeRole(_role, _user);
    }
}
