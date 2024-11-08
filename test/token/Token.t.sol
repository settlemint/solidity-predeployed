// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Token} from "../../contracts/token/Token.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TokenTest is Test {
    Token public token;
    address public admin;
    address public user1;
    address public user2;

    // Events
    event EmergencyWithdraw(address token, uint256 amount);

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);
        token = new Token("Test Token", "TEST", admin);
        vm.stopPrank();
    }

    function test_InitialState() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), admin));
        assertTrue(token.hasRole(token.BURNER_ROLE(), admin));
    }

    function test_Mint() public {
        vm.startPrank(admin);
        token.mint(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
        vm.stopPrank();
    }

    function testFail_MintUnauthorized() public {
        vm.prank(user1);
        token.mint(user1, 1000);
    }

    function testFail_MintToZeroAddress() public {
        vm.prank(admin);
        token.mint(address(0), 1000);
    }

    function testFail_MintZeroAmount() public {
        vm.prank(admin);
        token.mint(user1, 0);
    }

    function test_Burn() public {
        vm.startPrank(admin);
        token.mint(user1, 1000);
        token.burn(user1, 500);
        assertEq(token.balanceOf(user1), 500);
        vm.stopPrank();
    }

    function testFail_BurnUnauthorized() public {
        vm.prank(admin);
        token.mint(user1, 1000);

        vm.prank(user1);
        token.burn(user1, 500);
    }

    function testFail_BurnFromZeroAddress() public {
        vm.prank(admin);
        token.burn(address(0), 500);
    }

    function testFail_BurnZeroAmount() public {
        vm.prank(admin);
        token.burn(user1, 0);
    }

    function test_Pause() public {
        vm.startPrank(admin);
        token.pause();
        assertTrue(token.paused());

        vm.expectRevert();
        token.transfer(user2, 100);

        token.unpause();
        assertFalse(token.paused());
        vm.stopPrank();
    }

    function testFail_PauseUnauthorized() public {
        vm.prank(user1);
        token.pause();
    }

    function test_EmergencyWithdraw() public {
        // Setup test token and mint some to the Token contract
        Token testToken = new Token("Test Token 2", "TEST2", admin);
        vm.startPrank(admin);
        testToken.mint(address(token), 1000);
        
        // Grant ADMIN_ROLE to admin for emergencyWithdraw
        token.grantRole(token.ADMIN_ROLE(), admin);
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdraw(address(testToken), 1000);
        
        token.emergencyWithdraw(address(testToken), 1000);
        assertEq(testToken.balanceOf(admin), 1000);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawUnauthorized() public {
        vm.prank(user1);
        token.emergencyWithdraw(address(0), 100);
    }

    function test_Transfer() public {
        vm.prank(admin);
        token.mint(user1, 1000);

        vm.prank(user1);
        token.transfer(user2, 500);

        assertEq(token.balanceOf(user1), 500);
        assertEq(token.balanceOf(user2), 500);
    }

    function test_TransferFrom() public {
        vm.startPrank(admin);
        token.mint(user1, 1000);
        vm.stopPrank();

        vm.prank(user1);
        token.approve(user2, 500);

        vm.prank(user2);
        token.transferFrom(user1, address(this), 500);

        assertEq(token.balanceOf(user1), 500);
        assertEq(token.balanceOf(address(this)), 500);
    }

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);

        vm.prank(admin);
        token.mint(owner, 1000);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                            owner,
                            user1,
                            500,
                            0,
                            block.timestamp + 1 hours
                        )
                    )
                )
            )
        );

        token.permit(owner, user1, 500, block.timestamp + 1 hours, v, r, s);
        assertEq(token.allowance(owner, user1), 500);
    }

    function testFail_EmergencyWithdrawZeroAddress() public {
        vm.startPrank(admin);
        token.grantRole(token.ADMIN_ROLE(), admin);
        token.emergencyWithdraw(address(0), 100);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawZeroAmount() public {
        vm.startPrank(admin);
        token.grantRole(token.ADMIN_ROLE(), admin);
        token.emergencyWithdraw(address(this), 0);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawInsufficientBalance() public {
        Token testToken = new Token("Test Token 2", "TEST2", admin);
        
        vm.startPrank(admin);
        token.grantRole(token.ADMIN_ROLE(), admin);
        testToken.mint(address(token), 100);
        token.emergencyWithdraw(address(testToken), 200); // Try to withdraw more than balance
        vm.stopPrank();
    }

    function testFail_BurnInsufficientBalance() public {
        vm.startPrank(admin);
        token.mint(user1, 100);
        token.burn(user1, 200); // Try to burn more than balance
        vm.stopPrank();
    }

    function test_TimelockController() public {
        assertEq(address(token.timelock()), address(token.timelock()));
        assertTrue(token.timelock().hasRole(token.timelock().PROPOSER_ROLE(), admin));
        assertTrue(token.timelock().hasRole(token.timelock().EXECUTOR_ROLE(), admin));
        assertTrue(token.timelock().hasRole(token.timelock().CANCELLER_ROLE(), admin));
    }

    function testFail_ConstructorZeroAddress() public {
        new Token("Test Token", "TEST", address(0));
    }
}
