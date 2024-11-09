// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Token } from "../../contracts/token/Token.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

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

    function test_InitialState() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), admin));
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

    function test_MintToZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero recipient address"));
        token.mint(address(0), 1000);
        vm.stopPrank();
    }

    function test_MintZeroAmount() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero amount"));
        token.mint(user1, 0);
        vm.stopPrank();
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

    function test_BurnFromZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero address"));
        token.burn(address(0), 500);
        vm.stopPrank();
    }

    function test_BurnZeroAmount() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero amount"));
        token.burn(user1, 0);
        vm.stopPrank();
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
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
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

    function test_EmergencyWithdrawZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero token address"));
        token.emergencyWithdraw(address(0), 100);
        vm.stopPrank();
    }

    function test_EmergencyWithdrawZeroAmount() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero amount"));
        token.emergencyWithdraw(address(this), 0);
        vm.stopPrank();
    }

    function test_EmergencyWithdrawInsufficientBalance() public {
        Token testToken = new Token("Test Token 2", "TEST2", admin);
        vm.startPrank(admin);
        testToken.mint(address(token), 100);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidOperation.selector, "Insufficient balance"));
        token.emergencyWithdraw(address(testToken), 200);
        vm.stopPrank();
    }

    function test_BurnInsufficientBalance() public {
        vm.startPrank(admin);
        token.mint(user1, 100);
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidOperation.selector, "Insufficient balance"));
        token.burn(user1, 200);
        vm.stopPrank();
    }

    // Add this test to check constructor zero address validation
    function test_ConstructorZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Token.InvalidInput.selector, "Zero admin address"));
        new Token("Test Token", "TEST", address(0));
    }

    // Add these helper functions at the top of the contract
    function getPermitDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
    }

    function getPermitSignature(
        uint256 privateKey,
        address spender,
        uint256 value,
        uint256 deadline
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        address owner = vm.addr(privateKey);
        bytes32 digest = getPermitDigest(owner, spender, value, token.nonces(owner), deadline);
        (v, r, s) = vm.sign(privateKey, digest);
    }

    // Add these test functions
    function test_PermitApproval() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 amount = 1000e18;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(admin);
        token.mint(owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(privateKey, user1, amount, deadline);

        // Verify initial state
        assertEq(token.allowance(owner, user1), 0);
        assertEq(token.nonces(owner), 0);

        // Submit permit
        token.permit(owner, user1, amount, deadline, v, r, s);

        // Verify permit effect
        assertEq(token.allowance(owner, user1), amount);
        assertEq(token.nonces(owner), 1);

        // Test the approved transfer
        vm.prank(user1);
        token.transferFrom(owner, user2, amount);
        assertEq(token.balanceOf(user2), amount);
    }

    function test_PermitExpired() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 amount = 1000e18;
        uint256 deadline = block.timestamp - 1; // Expired deadline

        vm.prank(admin);
        token.mint(owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(privateKey, user1, amount, deadline);

        // Use the correct error selector for expired deadline
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ERC2612ExpiredSignature(uint256)")), deadline));
        token.permit(owner, user1, amount, deadline, v, r, s);
    }

    function test_PermitInvalidSignature() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 amount = 1000e18;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(admin);
        token.mint(owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(privateKey, user1, amount, deadline);

        // Try to use permit with wrong amount
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC2612InvalidSigner(address,address)")),
                0x0A48848e0C8b84A8ea071f96AE4036b9edCb8aF4,
                owner
            )
        );
        token.permit(owner, user1, amount + 1, deadline, v, r, s);
    }

    function testFuzz_Permit(uint256 privateKey, uint256 amount, uint256 deadline) public {
        // Bound privateKey to be less than the curve order
        privateKey = bound(privateKey, 1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140);
        vm.assume(privateKey != 0);

        // Bound amount and deadline
        amount = bound(amount, 1, type(uint128).max);
        deadline = bound(deadline, block.timestamp, type(uint64).max);

        address owner = vm.addr(privateKey);

        vm.prank(admin);
        token.mint(owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(privateKey, user1, amount, deadline);

        token.permit(owner, user1, amount, deadline, v, r, s);
        assertEq(token.allowance(owner, user1), amount);
        assertEq(token.nonces(owner), 1);

        vm.prank(user1);
        token.transferFrom(owner, user2, amount);
        assertEq(token.balanceOf(user2), amount);
    }
}

contract TokenFuzzTests is Test {
    Token public token;
    address public admin;
    address public user;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");

        vm.startPrank(admin);
        token = new Token("Test Token", "TEST", admin);
        vm.stopPrank();
    }

    function testFuzz_Mint(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1000, type(uint128).max);

        vm.startPrank(admin);
        token.mint(user, amount);
        assertEq(token.balanceOf(user), amount);
        vm.stopPrank();
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        // Bound amounts
        mintAmount = bound(mintAmount, 1000, type(uint128).max);

        vm.startPrank(admin);
        token.mint(user, mintAmount);

        burnAmount = bound(burnAmount, 1, mintAmount);
        token.burn(user, burnAmount);

        assertEq(token.balanceOf(user), mintAmount - burnAmount);
        vm.stopPrank();
    }

    function testFuzz_Transfer(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1000, type(uint128).max);

        vm.startPrank(admin);
        token.mint(user, amount);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 halfAmount = amount / 2;
        token.transfer(address(this), halfAmount);

        // Fix assertions to account for integer division
        assertEq(token.balanceOf(user), amount - halfAmount); // Changed from amount/2
        assertEq(token.balanceOf(address(this)), halfAmount);
        vm.stopPrank();
    }

    function testFuzz_EmergencyWithdraw(uint256 amount) public {
        // Create test token and mint some to the Token contract
        Token testToken = new Token("Test Token 2", "TEST2", admin);

        // Bound amount
        amount = bound(amount, 1000, type(uint128).max);

        vm.startPrank(admin);
        testToken.mint(address(token), amount);
        token.emergencyWithdraw(address(testToken), amount);
        assertEq(testToken.balanceOf(admin), amount);
        vm.stopPrank();
    }
}
