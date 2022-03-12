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

    uint256 public constant MAX_PILLS = 35520; // This will change after final collection settled
    string private _baseTokenURI; 
    string public baseExtension = ".json";
    bool public paused = true;
    
    address public SANTA_CONTRACT;
    address public GAINZ_CONTRACT;

    uint256 RED_PILL_PRICE = 4000 * 10 ** 18;
    // Events
    event GainzToPillSwap(address owner);
    //

    constructor(address _santaContract, address _gainzContract) ERC721("REDPILL", "REDPILL") {
        SANTA_CONTRACT = _santaContract;
        GAINZ_CONTRACT = _gainzContract;
    }

    function mintRedPill(address to, uint256 _gainzAmount) external nonReentrant {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.isGameActive() == true, "Game is not active!");
        require(_gainzAmount > 0 , "Must be greater than 0 $GAINZ");

        Gainz gainzContract = Gainz(GAINZ_CONTRACT);
        uint256 userGainzBalance = gainzContract.balanceOf(msg.sender);
        require(userGainzBalance >= RED_PILL_PRICE, "Not enough $GAINZ, srry");   

        // Burn Gainz First
        gainzContract.burnGainz(msg.sender, _gainzAmount);

        // Supply Red Pills
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function levelUp(uint256 santaId, uint256 redPillId) external nonReentrant {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.isGameActive() == true, "Game is not active!");
        require(ownerOf(redPillId) == msg.sender, "NOT REDPILL OWNER!");
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