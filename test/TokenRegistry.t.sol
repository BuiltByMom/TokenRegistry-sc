// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;
    TokentrollerV1 tokentroller;
    address owner = address(1);
    address nonOwner = address(2);
    address nonOwner2 = address(3);
    address tokenAddress = address(4);
    uint256 chainID = 1;

    function setUp() public {
        tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
    }

    function testAddToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint8 status, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress);

        assertEq(name, "Test Token");
        assertEq(symbol, "TTK");
        assertEq(logoURI, "https://example.com/logo.png");
        assertEq(decimals, 18);
        assertEq(status, 0);
        assertEq(chainID, chainID);
    }

    function testUpdateToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);
 
        vm.prank(nonOwner);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint8 status, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress);

        assertEq(name, "Updated Token", "Name should be updated");
        assertEq(symbol, "UTK", "Symbol should be updated");
        assertEq(logoURI, "https://example.com/new_logo.png", "Logo URI should be updated");
        assertEq(decimals, 9, "Decimals should be updated");
    }

    function testFastTrackToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        vm.prank(owner);
        tokenRegistry.fastTrackToken(chainID, tokenAddress);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint8 status, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress);
        assertEq(status, 1, 'Token should be fast-tracked');
    }

    function testRejectToken() public {
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        vm.prank(owner);
        tokenRegistry.rejectToken(chainID, tokenAddress);

        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint8 status, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress);
        assertEq(status, 2);
    }

    function testUpdateTokentroller() public {
        address newTokentroller = address(4);
        vm.prank(owner);
        tokentroller.updateRegistryTokentroller(newTokentroller);

        assertEq(tokenRegistry.tokentroller(), newTokentroller);
    }

    function testListAllTokens() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(uint160(i + 10)), string(abi.encodePacked("Token ", uintToStr(i))), string(abi.encodePacked("TK", uintToStr(i))), "https://example.com/logo.png", 18, chainID);
        }

        (TokenRegistry.Token[] memory tokens, uint256 finalIndex) = tokenRegistry.listAllTokens(chainID, 0, 3);
        assertEq(tokens.length, 3);
        assertEq(finalIndex, 2);
        assertEq(tokens[0].name, "Token 0");
        assertEq(tokens[2].name, "Token 2");
    }

    function testListApprovedTokens() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(uint160(i + 10)), string(abi.encodePacked("Token ", uintToStr(i))), string(abi.encodePacked("TK", uintToStr(i))), "https://example.com/logo.png", 18, chainID);
            if (i % 2 == 0) {
                vm.prank(owner);
                tokenRegistry.fastTrackToken(chainID, address(uint160(i + 10)));
            }
        }

        (TokenRegistry.Token[] memory tokens, uint256 finalIndex) = tokenRegistry.listApprovedTokens(chainID, 0, 3);
        assertEq(tokens.length, 3);
        assertEq(finalIndex, 4);
        assertEq(tokens[0].name, "Token 0");
        assertEq(tokens[1].name, "Token 2");
        assertEq(tokens[2].name, "Token 4");
    }

    function testTokenCount() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(nonOwner);
            tokenRegistry.addToken(address(uint160(i + 10)), string(abi.encodePacked("Token ", uintToStr(i))), string(abi.encodePacked("TK", uintToStr(i))), "https://example.com/logo.png", 18, chainID);
        }

        assertEq(tokenRegistry.tokenCount(chainID), 5);
    }

    function testAcceptTokenEdit() public {
        // Add a token
        vm.prank(nonOwner);
        tokenRegistry.addToken(tokenAddress, "Test Token", "TTK", "https://example.com/logo.png", 18, chainID);

        // Suggest an update
        vm.prank(nonOwner2);
        tokenRegistry.updateToken(tokenAddress, "Updated Token", "UTK", "https://example.com/new_logo.png", 9, chainID);

        // Accept the edit
        vm.prank(owner);
        tokenRegistry.acceptTokenEdit(tokenAddress, 1, chainID);

        // Retrieve the updated token
        (address contractAddress, address submitter, string memory name, string memory logoURI, string memory symbol, uint8 decimals, uint8 status, uint256 chainId) = tokenRegistry.tokens(chainID, tokenAddress);

        // Assert the token details have been updated
        assertEq(name, "Updated Token", 'Name should be updated');
        assertEq(symbol, "UTK", 'Symbol should be updated');
        assertEq(logoURI, "https://example.com/new_logo.png", 'Logo URI should be updated');
        assertEq(decimals, 9, 'Decimals should be updated');
        assertEq(status, 1, 'Status should be 1');
        assertEq(tokenRegistry.editCount(chainID, tokenAddress), 0, 'Edit count should be 0');
    }

    function testUpdateOwner() public {
        address newOwner = address(5);
        vm.prank(owner);
        tokentroller.updateOwner(newOwner);

        assertEq(tokentroller.owner(), newOwner);
    }

    function uintToStr(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }
}
