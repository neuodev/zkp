// SPDX-License-Identifier: MIT
// slither-disable-next-line solc-version
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// mocked methods of ZKPToken
contract TokenMock is ERC20Permit {
    constructor() ERC20Permit("TEST") ERC20("TEST", "TT") {
        _mint(msg.sender, 1e27);
    }
}

contract ERC721Mock is ERC721 {
    uint256 private _tokenId;

    // solhint-disable-next-line no-empty-blocks
    constructor() ERC721("TEST", "TT") {}

    function mintBatch(address _to, uint256 _amount) external {
        for (uint256 i = 0; i < _amount; i++) {
            _mint(_to, _tokenId);
            _tokenId++;
        }
    }

    function grantOneToken(address _to) external returns (uint256 id) {
        id = _tokenId;
        _mint(_to, id);

        _tokenId++;
    }
}
