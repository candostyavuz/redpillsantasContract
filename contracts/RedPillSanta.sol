// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./Authorizable.sol";

contract RedPillSanta is ERC721, ERC721Enumerable, Authorizable, ReentrancyGuard, IERC2981 {
    using Strings for uint256;

    // State Variables
    uint256 public constant MAX_SANTAS = 4000;
    string private _baseTokenURI;
    string public baseExtension = ".json";
    bool public paused = true;
    uint256 public mintPrice = 1.25 ether;  // 1.25 AVAX
    uint256 public _royaltyAmount = 50;     // 5% royalty

    uint256[4000] public remainingTokens;
    uint256 public remainingSupply = MAX_SANTAS;
    uint256 public lastMintedTokenId;

    address payable private admin1;
    address payable private admin2;
    address payable private admin3;
    address payable private prizePoolWallet;

    uint256 public gameStartTime;
    bool public isGameActive = false;

    mapping (uint256 => uint256) public tokenStrength;

    // If user transfers Santa into another wallet, Santas will go Cooldown
    // During this CD period, NFTs won't be allowed to be staked and cannot yield $GAINZ
    uint256 public TRANSFER_COOLDOWN_PERIOD = 1 days;
    mapping (uint256 => uint32) public tokenTransferCooldown;

    // Events
    event PrizePoolFunded(uint amount);
    event WinnerRewarded(address winner, uint256 amount);

    constructor(string memory _initBaseURI, address payable _admin1, address payable _admin2, address payable _admin3 , address payable _prizePoolWallet)
        ERC721("REDPILLSANTA", "REDPILLSANTA")
    {
        setBaseURI(_initBaseURI);
        setAdminAddress(_admin1, _admin2, _admin3,_prizePoolWallet);
    }

    function claimSanta(uint256 _amount) public payable nonReentrant {
        require(!paused, "Minting is paused!");
        require(msg.sender != address(0));
        require(_amount > 0, "Mint amount cannot be zero!");
        require(msg.value >= mintPrice * _amount, "Insufficient funds, ngmi.");
        require(remainingSupply >= _amount, "Amount exceeds the remaining supply!");
        require(_amount < 21, "Max 20 Santas can be minted in one order!");

        uint256 ownerTokenCount = balanceOf(msg.sender);
        require(ownerTokenCount <= 250, "Max 250 Santas are allowed per wallet!");

        for (uint256 i = 0; i < _amount; i++) {
            lastMintedTokenId = _mintRandomID(msg.sender);
            setBaseStrength(msg.sender, lastMintedTokenId);
        }
        distributeMintFee(msg.value);
    }

    function distributeMintFee(uint256 _fee) private {
        uint256 poolShare = (_fee * 60)/100;    // 60% of fees are added into the prize pool
        (prizePoolWallet).transfer(poolShare);

        uint256 perMemberShare = (_fee - poolShare)/3;
        (admin1).transfer(perMemberShare);
        (admin2).transfer(perMemberShare);
        (admin3).transfer(perMemberShare);
    }

    function _mintRandomID(address _to) internal returns (uint256) {
        uint256 _idx = _getEnoughRandom();
        uint256 _uniqueId = _getTokenId(_idx);
        remainingSupply--;
        remainingTokens[_idx] = _getTokenId(remainingSupply);
        _safeMint(_to, _uniqueId);
        return _uniqueId;
    }

    function _getTokenId(uint256 _idx) internal view returns (uint256) {
        if (remainingTokens[_idx] == 0) {
            return _idx;
        } else {
            return remainingTokens[_idx];
        }
    }

    /**
     * @dev Pseudo-random number generator
     * If you are determined to exploit this, you deserve the rare Santas TBH
     */
    function _getEnoughRandom() internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            ) % remainingSupply;
    }

    function setBaseStrength(address minter, uint256 tokenId) internal {
         require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        require ( minter == ownerOf(tokenId), "You are not the owner of this NFT");

        if(tokenId >= 0 && tokenId < 13) {               // unique
            tokenStrength[tokenId] = 500;
        } else if(tokenId >= 13 && tokenId < 1532){      // common
            tokenStrength[tokenId] = 30;
        } else if(tokenId >= 1532 && tokenId < 2807){    // cool
            tokenStrength[tokenId] = 90;
        } else if(tokenId >= 2807 && tokenId < 3604){    // rare
            tokenStrength[tokenId] = 200;
        } else if(tokenId >= 3604 && tokenId < 3922){    // epic
            tokenStrength[tokenId] = 300;
        } else if (tokenId >= 3922 && tokenId < 4000) {  // legendary
            tokenStrength[tokenId] = 400;
        } else {                                            // ERROR CONDITION!
            tokenStrength[tokenId] = 0;
        }
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

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount){
        if(tokenId >= 0 && tokenId < 13) {
            return (owner(), salePrice * (_royaltyAmount+10)/1000);
        } else {
            return (owner(), salePrice * (_royaltyAmount)/1000);
        }
    }

    // Only Owner functions

    function setRoyaltyAmount(uint256 number) external onlyOwner {
        _royaltyAmount = number;
    }
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        _baseTokenURI = _newBaseURI;
    }

    function setPrice(uint _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setBaseExtension(string memory _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    function setAdminAddress (address payable _admin1, address payable _admin2, address payable _admin3, address payable _prizePoolWallet) public onlyOwner {
        admin1 = _admin1;
        admin2 = _admin2;
        admin3 = _admin3;
        prizePoolWallet = _prizePoolWallet;
    }

    function setGameActive (bool _state) public onlyOwner {
        isGameActive = _state;
        gameStartTime = block.timestamp;
    }

    function fundTheWinner (address payable winner) external onlyAuthorized {
        require(isGameActive == true, "Game is not active!");
        require(address(this).balance != 0, "No funds!");
        require(msg.sender != address(0), "address 0 issue");

        uint256 prize = address(this).balance / 16;
        (winner).transfer(prize);

        emit WinnerRewarded(winner, prize);
    }

    function viewCurrentPrizePool() public view returns (uint256) {
        return address(this).balance;
    }

    // Will be used to add funds into the Prize Pool
    function addFunds() public payable onlyAuthorized {
        emit PrizePoolFunded(msg.value);
    }

    function setStrength(uint256 tokenId, uint256 _newStrength) external onlyAuthorized {
        require(!paused, "Contract is paused!");
        require(_newStrength <= 400, "Maximum upgradable strength is 400!");
        tokenStrength[tokenId] = _newStrength;
    }

    function setTransferCooldown(uint256 _period) external onlyOwner() {
        TRANSFER_COOLDOWN_PERIOD = _period;
    }

    function withdraw() external onlyOwner {
        require(address(this).balance != 0, "no funds");
        payable(msg.sender).transfer(address(this).balance);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
        tokenTransferCooldown[tokenId] = uint32(block.timestamp + TRANSFER_COOLDOWN_PERIOD);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

}
