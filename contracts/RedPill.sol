// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";   // For Gainz.sol 
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./RedPillSanta.sol";
import "./Gainz.sol";

contract RedPill is ERC721, ERC721Enumerable, ERC721Burnable, Authorizable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // State Variables
    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_PILLS = 35520; // This will change after the final collection is settled
    string private _baseTokenURI; 
    string public baseExtension = ".json";
    
    address public SANTA_CONTRACT;
    address public GAINZ_CONTRACT;

    uint256 public RED_PILL_PRICE = 450 * 10 ** 18;     // 1 RED PILL NFT = 450 $GAINZ

    // Events
    event MintRedPill(address owner);

    constructor(address _santaContract, address _gainzContract, string memory _initBaseURI) ERC721("REDPILL", "REDPILL") {
        SANTA_CONTRACT = _santaContract;
        GAINZ_CONTRACT = _gainzContract;
        setBaseURI(_initBaseURI);
    }

    // Swap $GAINZ with RedPill
    function mintRedPill(address to) external nonReentrant {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.isGameActive() == true, "Game is not active!");

        Gainz gainzContract = Gainz(GAINZ_CONTRACT);
        uint256 userGainzBalance = gainzContract.balanceOf(msg.sender);
        require(userGainzBalance >= RED_PILL_PRICE, "Not enough $GAINZ");   

        // Burn Gainz First
        gainzContract.burnGainz(msg.sender, RED_PILL_PRICE);

        // Supply Red Pills
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        // Unleash the event
        emit MintRedPill(to);
    }

    function levelUp(uint256 santaId, uint256 redPillId) external nonReentrant {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.isGameActive() == true, "Game is not active!");
        require(ownerOf(redPillId) == msg.sender, "NOT THE REDPILL OWNER!");
        require(santaContract.ownerOf(santaId) == msg.sender, "NOT SANTA OWNER!");

        uint256 ownerPillCount = balanceOf(msg.sender);
        require(ownerPillCount >= 1, "Red Pills required!");

        Gainz gainzContract = Gainz(GAINZ_CONTRACT);
        // Other require's are done inside Gainz.sol/takeRedPill

        // Burn Red Pill
        burn(redPillId);

        // Tier-up the santa, GMI!
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

    // Only Owner functions
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
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}