// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { CREATEX_ADDRESS, CREATEX_EXTCODEHASH, CREATEX_BYTECODE } from "./CreateX.d.sol";

import { ICreateX } from "./ICreateX.sol";

/**
 * @title CreateX Factory - Forge Script base
 * @author @radeksvarz (@radk)
 * @dev To be inherited by the deployment script
 */
abstract contract CreateXScript is Script {
    ICreateX internal constant CreateX = ICreateX(CREATEX_ADDRESS);

    /**
     * Modifier for the `setUp()` function
     */
    modifier withCreateX() {
        setUpCreateXFactory();
        _;
    }

    /**
     * @notice Check whether CreateX factory is deployed
     * If not, deploy when running within Forge internal testing VM (chainID 31337)
     */
    function setUpCreateXFactory() internal {
        if (!isCreateXDeployed()) {
            deployCreateX();
            if (!isCreateXDeployed()) revert("\u001b[91m Could not deploy CreateX! \u001b[0m");
        } else {
            console2.log("\u001b[92m\u2714 CreateX already deployed on chain:", block.chainid, "\u001b[0m");
        }

        vm.label(CREATEX_ADDRESS, "CreateX");
    }

    /**
     * @notice Returns true when CreateX factory is deployed, false if not.
     * Reverts if some other code is deployed to the CreateX address.
     */
    function isCreateXDeployed() internal view returns (bool) {
        bytes32 extCodeHash = address(CREATEX_ADDRESS).codehash;

        // CreateX runtime code is deployed
        if (extCodeHash == CREATEX_EXTCODEHASH) return true;

        // CreateX runtime code is not deployed, account without a code
        if (extCodeHash == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470) return false;

        // CreateX runtime code is not deployed, non existent account
        if (extCodeHash == 0) return false;

        // forgefmt: disable-start
        revert(
            string(
                abi.encodePacked(
                    "\n\n\u001b[91m"
                    "\u256d\u2500\u2500\u2500\u2500\u2504\u2508\n"
                    "\u2502 \u26a0 Warning! Some other contract is deployed to the CreateX address!\n"
                    "\u250a On the chain ID: ",
                    vm.toString(block.chainid),
                    "\u001b[0m"
                )
            )
        );
        // forgefmt: disable-end
    }

    /**
     * @notice Deploys CreateX factory if running within a local dev env
     */
    function deployCreateX() internal {
        // forgefmt: disable-start
        if (block.chainid != 31337) {
            revert(
                string(
                    abi.encodePacked(
                        "\n\n\u001b[91m"
                        "\u256d\u2500\u2500\u2500\u2500\u2504\u2508\n"
                        "\u2502 CreateX is not deployed on this chain ID: ",
                        vm.toString(block.chainid),
                        "\n"
                        "\u250a Not on local dev env, CreateX cannot be etched! \n"
                        "\u001b[0m"
                    )
                )
            );
        }
        // forgefmt: disable-end

        console2.log("\u2692 Etching missing CreateX on chain:", block.chainid);
        vm.etch(CREATEX_ADDRESS, CREATEX_BYTECODE);
    }

    /**
     * @notice Pre-computes the target address based on the adjusted salt
     */
    function computeCreate3Address(bytes32 salt, address deployer) public pure returns (address) {
        // Adjusts salt in the way CreateX adjusts for front running protection
        // see: https://github.com/pcaversaccio/createx/blob/52bb3158d4af791469f84b4797d2806db500ac4d/src/CreateX.sol#L893
        // bytes32 guardedSalt = _efficientHash({a: bytes32(uint256(uint160(deployer))), b: salt});

        bytes32 guardedSalt = keccak256(abi.encodePacked(uint256(uint160(deployer)), salt));

        return CreateX.computeCreate3Address(guardedSalt, CREATEX_ADDRESS);
    }

    /**
     * @notice Deploys the contract via CREATE3
     */
    function create3(bytes32 salt, bytes memory initCode) public returns (address) {
        return CreateX.deployCreate3(salt, initCode);
    }
}
