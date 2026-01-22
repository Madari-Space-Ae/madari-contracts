// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BucketRegistry.sol";

/**
 * @title DeployTest
 * @notice Simple test deployment to verify Madari L1 testnet works
 * @dev Run with: forge script script/DeployTest.s.sol --rpc-url $MADARI_TESTNET_RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
contract DeployTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BucketRegistry as a simple test
        BucketRegistry bucketRegistry = new BucketRegistry();
        console.log("BucketRegistry deployed at:", address(bucketRegistry));

        vm.stopBroadcast();

        console.log("Test deployment successful!");
    }
}
