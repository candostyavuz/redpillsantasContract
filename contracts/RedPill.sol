// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Authorizable.sol";
import "./RedPillSanta.sol";
import "./Gainz.sol";

contract RedPill is ERC721, ERC721Enumerable, ERC721Burnable, Authorizable, ReentrancyGuard, IERC2981 {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // State Variables
    Counters.Counter private _tokenIdCounter;

    bool public paused = false;

    uint256 public constant MAX_PILLS = 11817;
    string private _baseTokenURI; 
    string public baseExtension = ".json";
    uint256 public _royaltyAmount = 50;     // 5% royalty

    address public SANTA_CONTRACT;
    address public GAINZ_CONTRACT;

    uint256 public RED_PILL_PRICE = 550 * 10 ** 18;     // 1 RED PILL NFT = 550 $GAINZ

    // Events
    event MintRedPill(address owner, uint256 amount);

    constructor(address _santaContract, address _gainzContract, string memory _initBaseURI) ERC721("REDPILL", "REDPILL") {
        setSantaContract(_santaContract);
        setGainzontract(_gainzContract);
        setBaseURI(_initBaseURI);
    }

    // Swap $GAINZ with RedPill
    function mintRedPill(uint256 _amount) external nonReentrant {
        require(!paused, "RP minting is paused!");

        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.isGameActive() == true, "Game is not active!");

        Gainz gainzContract = Gainz(GAINZ_CONTRACT);
        uint256 userGainzBalance = gainzContract.balanceOf(msg.sender);
        require(userGainzBalance >= RED_PILL_PRICE * _amount, "Not enough $GAINZ");   
        require(_tokenIdCounter.current() + _amount <= MAX_PILLS,
            "Amount exceeds remaining supply!");

        // Burn Gainz First
        gainzContract.burnGainz(msg.sender, RED_PILL_PRICE * _amount);

        for (uint256 i = 0; i < _amount; i++) {
            // Supply Red Pills
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
        }
        // Unleash the event
        emit MintRedPill(msg.sender, _amount);
    }

    function levelUp(uint256 santaId, uint256 redPillId) external nonReentrant {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(ownerOf(redPillId) == msg.sender, "NOT THE REDPILL OWNER!");
        require(santaContract.ownerOf(santaId) == msg.sender, "NOT SANTA OWNER!");
        // Other require's are done inside Gainz.sol/takeRedPill

        // Burn Red Pill
        burn(redPillId);

        // Tier-up the santa, GMI!
        Gainz gainzContract = Gainz(GAINZ_CONTRACT);
        gainzContract.takeRedPill(santaId);
    }

    function tokensOfOwner(address _owner) public view returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)): "";
    }

    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount){
        if(tokenId >= 0 && tokenId < 11817) {
            return (owner(), salePrice * (_royaltyAmount)/1000);
        }
    }
    // Only Owner functions
    function airDropRedPill(address _to, uint256 _amount) external onlyOwner {
        require(_tokenIdCounter.current() + _amount <= MAX_PILLS, "Amount exceeds remaining supply!");
        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
             _safeMint(_to, tokenId);
        }
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setSantaContract(address _santaContract) public onlyOwner {
        SANTA_CONTRACT = _santaContract;
    }

    function setGainzontract(address _gainzContract) public onlyOwner {
        GAINZ_CONTRACT = _gainzContract;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        _baseTokenURI = _newBaseURI;
    }

    function setBaseExtension(string memory _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    //Red Pill $GAINZ price
    function setRedPillPrice(uint _newPrice) external onlyOwner {
        RED_PILL_PRICE = _newPrice * 10 ** 18;
    }

    function setRoyaltyAmount(uint256 number) external onlyOwner {
        _royaltyAmount = number;
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}