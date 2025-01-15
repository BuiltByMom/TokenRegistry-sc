// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/Helper.sol";
import "src/TokenEdits.sol";
import "src/TokenRegistry.sol";
import "src/TokentrollerV1.sol";
import "src/TokenMetadataEdits.sol";
import "src/TokenMetadataRegistry.sol";
import "src/interfaces/ITokenRegistry.sol";

contract HelperTest is Test {
    Helper helper;
    TokenRegistry tokenRegistry;
    TokenMetadataRegistry metadataRegistry;
    TokenMetadataEdits metadataEdits;
    TokenEdits tokenEdits;
    address owner = address(1);
    address nonOwner = address(2);
    address tokenAddress = address(4);
    uint256 chainID = 1;

    function setUp() public {
        TokentrollerV1 tokentroller = new TokentrollerV1(owner);
        tokenRegistry = TokenRegistry(tokentroller.tokenRegistry());
        metadataRegistry = TokenMetadataRegistry(tokentroller.metadataRegistry());
        tokenEdits = TokenEdits(tokentroller.tokenEdits());
        metadataEdits = TokenMetadataEdits(tokentroller.metadataEdits());
        helper = new Helper(
            address(tokenRegistry),
            address(tokenEdits),
            address(metadataRegistry),
            address(metadataEdits)
        );
    }

    function testProposeEditWithMetadata() public {
        // Add and approve token first
        vm.prank(nonOwner);
        tokenRegistry.addToken(chainID, tokenAddress, "Test Token", "TEST", "logo", 18);
        vm.prank(owner);
        tokenRegistry.approveToken(chainID, tokenAddress);

        // Setup metadata field
        vm.prank(owner);
        metadataRegistry.addMetadataField("website");

        // Prepare metadata updates
        MetadataInput[] memory updates = new MetadataInput[](1);
        updates[0] = MetadataInput({ field: "website", value: "https://example.com" });

        // Propose both edits
        vm.prank(nonOwner);
        helper.proposeEditWithMetadata(tokenAddress, "Updated Token", "UTEST", "newlogo", 18, chainID, updates);

        // Verify token edit was proposed
        (TokenEdits.TokenEdit[] memory edits, uint256 finalIndex, bool hasMore) = tokenEdits.listEdits(chainID, 0, 1);
        TokenEdits.TokenEdit memory tokenEdit = edits[0];
        assertEq(tokenEdit.name, "Updated Token");
        assertEq(tokenEdit.symbol, "UTEST");

        // Verify metadata edit was proposed
        (
            TokenMetadataEdits.MetadataEditInfo[] memory metadataEditsData,
            uint256 metadataFinalIndex,
            bool metadataHasMore
        ) = metadataEdits.listAllEdits(chainID, 0, 1);

        assertEq(metadataEditsData.length, 1);
        assertEq(metadataEditsData[0].updates[0].value, "https://example.com");
    }

    function testAddTokenWithMetadata() public {
        // Add fields first
        vm.startPrank(owner);
        metadataRegistry.addMetadataField("website");
        metadataRegistry.addMetadataField("twitter");
        vm.stopPrank();

        // Prepare metadata inputs
        MetadataInput[] memory metadata = new MetadataInput[](2);
        metadata[0] = MetadataInput({ field: "website", value: "https://example.com" });
        metadata[1] = MetadataInput({ field: "twitter", value: "@example" });

        // Add token with metadata
        vm.prank(nonOwner);
        helper.addTokenWithMetadata(chainID, tokenAddress, "Test Token", "TEST", "https://logo.com", 18, metadata);

        // Verify metadata was set
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "website"), "https://example.com");
        assertEq(metadataRegistry.getMetadata(tokenAddress, chainID, "twitter"), "@example");
    }

    function testCannotAddTokenWithInvalidMetadataField() public {
        // Prepare metadata inputs with invalid field
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "invalid_field", value: "some value" });

        vm.prank(nonOwner);
        vm.expectRevert("Invalid field");
        helper.addTokenWithMetadata(chainID, tokenAddress, "Test Token", "TEST", "https://logo.com", 18, metadata);
    }
}
