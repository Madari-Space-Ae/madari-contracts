// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { TestERC20 } from "../test/mocks/TestERC20.sol";

/**
 * @title DeployTestERC20
 * @notice Deployment script for TestERC20 token on Madari L1
 *
 * Usage:
 *   forge script script/DeployTestERC20.s.sol:DeployTestERC20 \
 *     --rpc-url $MADARI_L1_RPC_URL \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast
 */
contract DeployTestERC20 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy with 1,000,000 initial supply
        TestERC20 token = new TestERC20(
            "Madari Test Token",
            "MTT",
            1_000_000 // 1 million tokens
        );

        console.log("TestERC20 deployed at:", address(token));
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply());
        console.log("Owner:", token.owner());

        vm.stopBroadcast();
    }
}
