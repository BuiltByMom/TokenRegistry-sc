// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/controllers/HyperlaneLeafPlugin.sol";
import "../src/TokenRegistry.sol";
import "../src/TokenEdits.sol";
import "../src/interfaces/ISharedTypes.sol";

contract GasEstimator is Script {
    function createTokenEdit(address tokenEdits, address token) internal {
        // Create a test edit
        MetadataInput[] memory metadata = new MetadataInput[](1);
        metadata[0] = MetadataInput({ field: "logoURI", value: "https://example.com/new_logo.png" });

        // Propose the edit
        TokenEdits(tokenEdits).proposeEdit(token, metadata);
    }

    function approveTokenIfNeeded(address leafPlugin, address token) internal {
        // Get token registry
        address tokenRegistry = HyperlaneLeafPlugin(leafPlugin).tokenRegistry();

        // Check current status
        uint8 status = uint8(TokenRegistry(tokenRegistry).tokenStatus(token));

        // If not approved (status 1), approve it
        if (status != 1) {
            // APPROVED = 1
            // Craft and execute approve message
            IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
            bytes memory message = abi.encodeWithSignature("executeApproveToken(address)", token);
            uint32 origin = 1;
            bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

            vm.prank(address(mailbox));
            HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        }
    }

    function estimateExecuteApproveToken(address leafPlugin, address token) external returns (uint256) {
        // Get the mailbox address
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();

        // Craft the message bytes
        bytes memory message = abi.encodeWithSignature("executeApproveToken(address)", token);

        // Create a fake origin and sender that would pass the checks
        uint32 origin = 1; // Example origin chain ID
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        // Simulate the call as mailbox
        vm.startPrank(address(mailbox));

        // Measure gas
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();

        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteRejectToken(
        address leafPlugin,
        address token,
        string calldata reason
    ) external returns (uint256) {
        // Get the mailbox address
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();

        // Craft the message bytes
        bytes memory message = abi.encodeWithSignature("executeRejectToken(address,string)", token, reason);

        // Create a fake origin and sender that would pass the checks
        uint32 origin = 1; // Example origin chain ID
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        // Simulate the call as mailbox
        vm.startPrank(address(mailbox));

        // Measure gas
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();

        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteAcceptTokenEdit(
        address leafPlugin,
        address token,
        uint256 editId
    ) external returns (uint256) {
        // Ensure token is approved first
        approveTokenIfNeeded(leafPlugin, token);

        // Create an edit
        address tokenEdits = HyperlaneLeafPlugin(leafPlugin).tokenEdits();
        createTokenEdit(tokenEdits, token);
        createTokenEdit(tokenEdits, token);
        createTokenEdit(tokenEdits, token);

        // Continue with existing estimation logic
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
        bytes memory message = abi.encodeWithSignature("executeAcceptTokenEdit(address,uint256)", token, editId);

        uint32 origin = 1;
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        vm.startPrank(address(mailbox));
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteRejectTokenEdit(
        address leafPlugin,
        address token,
        uint256 editId,
        string calldata reason
    ) external returns (uint256) {
        // Ensure token is approved first
        approveTokenIfNeeded(leafPlugin, token);

        // Create an edit
        address tokenEdits = HyperlaneLeafPlugin(leafPlugin).tokenEdits();
        createTokenEdit(tokenEdits, token);

        // Continue with existing estimation logic
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
        bytes memory message = abi.encodeWithSignature(
            "executeRejectTokenEdit(address,uint256,string)",
            token,
            editId,
            reason
        );

        uint32 origin = 1;
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        vm.startPrank(address(mailbox));
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteAddMetadataField(address leafPlugin, string calldata name) external returns (uint256) {
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
        bytes memory message = abi.encodeWithSignature("executeAddMetadataField(string)", name);

        uint32 origin = 1;
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        vm.startPrank(address(mailbox));
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteUpdateMetadataField(
        address leafPlugin,
        string calldata name,
        bool isActive,
        bool isRequired
    ) external returns (uint256) {
        // First add the field if it doesn't exist
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
        bytes memory addMessage = abi.encodeWithSignature("executeAddMetadataField(string)", name);

        uint32 origin = 1;
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        // Add the field first
        vm.prank(address(mailbox));
        try HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, addMessage) {
            // Field was added successfully
        } catch {
            // Field might already exist, continue with update
        }

        // Now update the field
        bytes memory updateMessage = abi.encodeWithSignature(
            "executeUpdateMetadataField(string,bool,bool)",
            name,
            isActive,
            isRequired
        );

        vm.startPrank(address(mailbox));
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, updateMessage);
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteUpdateRegistryTokentroller(
        address leafPlugin,
        address newTokentroller
    ) external returns (uint256) {
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
        bytes memory message = abi.encodeWithSignature("updateRegistryTokentroller(address)", newTokentroller);

        uint32 origin = 1;
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        vm.startPrank(address(mailbox));
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();

        return gasUsed;
    }

    function estimateExecuteUpdateMetadataTokentroller(
        address leafPlugin,
        address newTokentroller
    ) external returns (uint256) {
        IMailbox mailbox = HyperlaneLeafPlugin(leafPlugin).mailbox();
        bytes memory message = abi.encodeWithSignature("updateMetadataTokentroller(address)", newTokentroller);

        uint32 origin = 1;
        bytes32 sender = bytes32(uint256(uint160(HyperlaneLeafPlugin(leafPlugin).root())));

        vm.startPrank(address(mailbox));
        uint256 startGas = gasleft();
        HyperlaneLeafPlugin(leafPlugin).handle(origin, sender, message);
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();

        return gasUsed;
    }
}
