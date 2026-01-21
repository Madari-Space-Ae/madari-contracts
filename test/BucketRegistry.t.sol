// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BucketRegistry.sol";

contract BucketRegistryTest is Test {
    BucketRegistry public registry;

    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        registry = new BucketRegistry();
    }

    function test_CreateBucket() public {
        vm.prank(alice);
        bytes32 bucketId = registry.createBucket("my-bucket", keccak256("key"));

        assertTrue(registry.bucketExists(bucketId));
        assertEq(registry.getOwner(bucketId), alice);

        BucketRegistry.Bucket memory bucket = registry.getBucket(bucketId);
        assertEq(bucket.name, "my-bucket");
        assertEq(bucket.owner, alice);
    }

    function test_CreateBucket_UniquePerOwner() public {
        vm.startPrank(alice);
        bytes32 bucketId1 = registry.createBucket("bucket", keccak256("key1"));

        vm.expectRevert("Name already exists");
        registry.createBucket("bucket", keccak256("key2"));
        vm.stopPrank();

        // Bob can create same name
        vm.prank(bob);
        bytes32 bucketId2 = registry.createBucket("bucket", keccak256("key3"));

        assertTrue(bucketId1 != bucketId2);
    }

    function test_DeleteBucket() public {
        vm.startPrank(alice);
        bytes32 bucketId = registry.createBucket("to-delete", keccak256("key"));
        assertTrue(registry.bucketExists(bucketId));

        registry.deleteBucket(bucketId);
        assertFalse(registry.bucketExists(bucketId));
        vm.stopPrank();
    }

    function test_DeleteBucket_OnlyOwner() public {
        vm.prank(alice);
        bytes32 bucketId = registry.createBucket("protected", keccak256("key"));

        vm.prank(bob);
        vm.expectRevert("Not owner");
        registry.deleteBucket(bucketId);
    }

    function test_ListBuckets() public {
        vm.startPrank(alice);
        bytes32 id1 = registry.createBucket("bucket-1", keccak256("key1"));
        bytes32 id2 = registry.createBucket("bucket-2", keccak256("key2"));
        vm.stopPrank();

        bytes32[] memory buckets = registry.listBuckets(alice);
        assertEq(buckets.length, 2);
        assertEq(buckets[0], id1);
        assertEq(buckets[1], id2);
    }

    function testFuzz_CreateBucket(string calldata name) public {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(name).length <= 63);

        vm.prank(alice);
        bytes32 bucketId = registry.createBucket(name, keccak256("key"));
        assertTrue(registry.bucketExists(bucketId));
    }
}
