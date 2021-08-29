pragma solidity 0.8.0;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";
import "./uniswap/IUniswapV2Router02.sol";
import "./erc20/IERC20.sol";
import "./utils/SafeMath.sol";

contract Flashloan is FlashLoanReceiverBase {
    
    using SafeMath for uint256;

    IUniswapV2Router02 kovanUniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    
    address kovanUsdc = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address kovanHex = 0x9a8f5EbB5B2ED381C8B1116b8CAf55D3b17eA3aa;
    address kovanEth = kovanUniswapRouter.WETH();

    constructor(address _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        /**
         * Step1: Borrow 250,000 usdc from Aave
         * Step2: exchange 50,000 usdc for Hex;
         * Step3: Exchange the Hex for ETH.
         * Step4: Exchange the ETH for USDC.
         * Step5: Repeat 2-4 the above 5 more times.
        */
        address[] memory path1 = new address[](3);
        path1[0] = kovanUsdc;
        path1[1] = kovanEth;
        path1[2] = kovanHex;
        IERC20(kovanUsdc).approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        kovanUniswapRouter.swapExactTokensForTokens(0.2 * 1e18, 1, path1, address(this), block.timestamp);
        uint256 hexAmount1 = IERC20(kovanHex).balanceOf(address(this));
        address[] memory path2 = new address[](2);
        path2[0] = kovanHex;
        path2[1] = kovanEth;
        IERC20(kovanHex).approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        kovanUniswapRouter.swapExactTokensForETH(hexAmount1, 1, path2, address(this), block.timestamp);
        address[] memory path3 = new address[](2);
        path3[0] = kovanEth;
        path3[1] = kovanUsdc;
        kovanUniswapRouter.swapExactETHForTokens{value: address(this).balance}(1, path3, address(this), block.timestamp);
        for(uint8 i = 0; i < 4; i++) {
            kovanUniswapRouter.swapExactTokensForTokens(0.2 * 1e18, 1, path1, address(this), block.timestamp);
            hexAmount1 = IERC20(kovanHex).balanceOf(address(this));
            kovanUniswapRouter.swapExactTokensForETH(hexAmount1, 1, path2, address(this), block.timestamp);
            kovanUniswapRouter.swapExactETHForTokens{value: address(this).balance}(1, path3, address(this), block.timestamp);
        }
        
        /**
         * Then take the 200,000 usdc and exchange for ETH,
         * Then exchange the ETH for HEX,
         * Then exchange the HEX back to USDC.
        */
        address[] memory path4 = new address[](2);
        path4[0] = kovanUsdc;
        path4[1] = kovanEth;
        kovanUniswapRouter.swapExactTokensForETH(0.8 * 1e18, 1, path4, address(this), block.timestamp);
        address[] memory path5 = new address[](2);
        path5[0] = kovanEth;
        path5[1] = kovanHex;
        kovanUniswapRouter.swapExactETHForTokens{value: address(this).balance}(1, path5, address(this), block.timestamp);
        address[] memory path6 = new address[](3);
        path6[0] = kovanHex;
        path6[1] = kovanEth;
        path6[2] = kovanUsdc;
        hexAmount1 = IERC20(kovanHex).balanceOf(address(this));
        kovanUniswapRouter.swapExactTokensForTokens(hexAmount1, 1, path6, address(this), block.timestamp);
        

        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));
    }

    /**
        Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan() public onlyOwner { // usdc loan address
        bytes memory data = "";
        uint amount = 1 * 1e18; // 2.5 * 1e5

        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), kovanUsdc, amount, data);
    }
}
