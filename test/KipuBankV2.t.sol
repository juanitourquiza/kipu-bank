// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {KipuBankV2} from "../src/KipuBankV2.sol";

/**
 * @title KipuBankV2Test
 * @notice Tests básicos para KipuBankV2
 * @dev Tests para funcionalidad core del contrato
 */
contract KipuBankV2Test is Test {
    KipuBankV2 public kipuBank;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 public constant BANK_CAP_USD = 1_000_000_000; // 1,000 USD
    uint256 public constant WITHDRAWAL_LIMIT_USD = 100_000_000; // 100 USD
    
    // Mock price feed address (en tests reales usaríamos un mock)
    address public constant MOCK_ETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        kipuBank = new KipuBankV2(
            BANK_CAP_USD,
            WITHDRAWAL_LIMIT_USD,
            owner
        );
    }
    
    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Deployment() public {
        assertEq(kipuBank.i_bankCapUSD(), BANK_CAP_USD);
        assertEq(kipuBank.i_withdrawalLimitUSD(), WITHDRAWAL_LIMIT_USD);
        assertEq(kipuBank.owner(), owner);
    }
    
    function test_Constants() public {
        assertEq(kipuBank.ACCOUNTING_DECIMALS(), 6);
        assertEq(kipuBank.ETH_ADDRESS(), address(0));
    }
    
    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_OnlyOwnerCanAddToken() public {
        address mockToken = makeAddr("mockToken");
        address mockPriceFeed = makeAddr("mockPriceFeed");
        
        vm.prank(user1);
        vm.expectRevert();
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
        
        // Owner puede agregar
        vm.prank(owner);
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
        
        assertTrue(kipuBank.isTokenSupported(mockToken));
    }
    
    function test_OnlyOwnerCanRemoveToken() public {
        address mockToken = makeAddr("mockToken");
        address mockPriceFeed = makeAddr("mockPriceFeed");
        
        vm.prank(owner);
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
        
        vm.prank(user1);
        vm.expectRevert();
        kipuBank.removeSupportedToken(mockToken);
        
        // Owner puede remover
        vm.prank(owner);
        kipuBank.removeSupportedToken(mockToken);
        
        assertFalse(kipuBank.isTokenSupported(mockToken));
    }
    
    /*//////////////////////////////////////////////////////////////
                        TOKEN SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_AddETHSupport() public {
        vm.prank(owner);
        kipuBank.addETHSupport(MOCK_ETH_PRICE_FEED);
        
        assertTrue(kipuBank.isTokenSupported(address(0)));
        
        KipuBankV2.TokenInfo memory tokenInfo = kipuBank.getTokenInfo(address(0));
        assertEq(tokenInfo.decimals, 18);
        assertEq(tokenInfo.priceFeed, MOCK_ETH_PRICE_FEED);
        assertTrue(tokenInfo.isSupported);
    }
    
    function test_CannotAddTokenTwice() public {
        address mockToken = makeAddr("mockToken");
        address mockPriceFeed = makeAddr("mockPriceFeed");
        
        vm.startPrank(owner);
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
        
        vm.expectRevert(KipuBankV2.KipuBankV2__TokenAlreadySupported.selector);
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
        vm.stopPrank();
    }
    
    function test_CannotAddTokenWithInvalidPriceFeed() public {
        address mockToken = makeAddr("mockToken");
        
        vm.prank(owner);
        vm.expectRevert(KipuBankV2.KipuBankV2__InvalidPriceFeed.selector);
        kipuBank.addSupportedToken(mockToken, address(0), 18);
    }
    
    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CannotDepositUnsupportedToken() public {
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        vm.expectRevert(KipuBankV2.KipuBankV2__TokenNotSupported.selector);
        kipuBank.depositETH{value: 0.1 ether}();
    }
    
    function test_CannotDepositZeroAmount() public {
        vm.prank(owner);
        kipuBank.addETHSupport(MOCK_ETH_PRICE_FEED);
        
        vm.prank(user1);
        vm.expectRevert(KipuBankV2.KipuBankV2__AmountMustBeGreaterThanZero.selector);
        kipuBank.depositETH{value: 0}();
    }
    
    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_GetUserBalanceReturnsZeroInitially() public {
        uint256 balance = kipuBank.getUserBalance(user1, address(0));
        assertEq(balance, 0);
    }
    
    function test_IsTokenSupportedReturnsFalseForUnsupported() public {
        assertFalse(kipuBank.isTokenSupported(makeAddr("randomToken")));
    }
    
    /*//////////////////////////////////////////////////////////////
                        COUNTER TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CountersInitializeToZero() public {
        assertEq(kipuBank.s_totalDeposits(), 0);
        assertEq(kipuBank.s_totalWithdrawals(), 0);
        assertEq(kipuBank.s_depositCountByUser(user1), 0);
        assertEq(kipuBank.s_withdrawalCountByUser(user1), 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                        EVENTS TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_TokenAddedEventEmitted() public {
        address mockToken = makeAddr("mockToken");
        address mockPriceFeed = makeAddr("mockPriceFeed");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit KipuBankV2.TokenAdded(mockToken, mockPriceFeed, 18);
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
    }
    
    function test_TokenRemovedEventEmitted() public {
        address mockToken = makeAddr("mockToken");
        address mockPriceFeed = makeAddr("mockPriceFeed");
        
        vm.startPrank(owner);
        kipuBank.addSupportedToken(mockToken, mockPriceFeed, 18);
        
        vm.expectEmit(true, false, false, false);
        emit KipuBankV2.TokenRemoved(mockToken);
        kipuBank.removeSupportedToken(mockToken);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                        RECEIVE FUNCTION TEST
    //////////////////////////////////////////////////////////////*/
    
    function test_ReceiveFunctionReverts() public {
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        (bool success, ) = address(kipuBank).call{value: 0.1 ether}("");
        assertFalse(success);
    }
}
