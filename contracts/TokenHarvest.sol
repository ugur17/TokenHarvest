// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract TokenHarvest is ERC20, Ownable {
//     constructor(address initialOwner) ERC20("TokenHarvest", "HST") Ownable(initialOwner) {
//         _mint(msg.sender, 10000 * 10 ** decimals());
//     }
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TokenHarvest is ERC1155 {
    address public owner;
    mapping(string => uint256) public nameToCounter;

    constructor() ERC1155("https://api.tokenharvest.com/token/{id}.json") {
        owner = msg.sender;
    }

    function mintNFT(string memory _farmerName, uint256 _quantity) external {
        // Sadece sahibin nft oluşturmasına izin ver
        require(msg.sender == owner, "Only owner can mint tokens");

        // İlgili isim için karşılık gelen sayaç değerini al
        uint256 counter = nameToCounter[_farmerName];

        // Yeni token ID'si oluştur
        uint256 tokenId = uint256(keccak256(abi.encodePacked(_farmerName, counter)));

        // Yeni tokenları oluştur ve ilgili miktarda gönder
        _mint(msg.sender, tokenId, _quantity, "");

        // Sayaç değerini artır
        nameToCounter[_farmerName] = counter + 1;
    }
}
