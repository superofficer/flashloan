pragma solidity 0.8.0;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";
import "./uniswap/IUniswapV2Router02.sol";
import "./erc20/IERC20.sol";
import "./utils/SafeMath.sol";

contract Flashloan is FlashLoanReceiverBase {
    
    using SafeMath for uint256;

    address uniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address usdc = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD; // mainnet 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address hex = 0x9a8f5EbB5B2ED381C8B1116b8CAf55D3b17eA3aa; // mainnet 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39

    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(uniswapV2Router02);
    address eth = uniswapRouter.WETH();

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
        path1[0] = usdc;
        path1[1] = eth;
        path1[2] = hex;
        IERC20(usdc).approve(uniswapV2Router02, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        uniswapRouter.swapExactTokensForTokens(5 * 1e4 * 1e18, 1, path1, address(this), block.timestamp);
        uint256 hexAmount1 = IERC20(hex).balanceOf(address(this));
        address[] memory path2 = new address[](2);
        path2[0] = hex;
        path2[1] = eth;
        IERC20(hex).approve(uniswapV2Router02, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        uniswapRouter.swapExactTokensForETH(hexAmount1, 1, path2, address(this), block.timestamp);
        address[] memory path3 = new address[](2);
        path3[0] = eth;
        path3[1] = usdc;
        uniswapRouter.swapExactETHForTokens{value: address(this).balance}(1, path3, address(this), block.timestamp);
        for(uint8 i = 0; i < 4; i++) {
            uniswapRouter.swapExactTokensForTokens(5 * 1e4 * 1e18, 1, path1, address(this), block.timestamp);
            hexAmount1 = IERC20(hex).balanceOf(address(this));
            uniswapRouter.swapExactTokensForETH(hexAmount1, 1, path2, address(this), block.timestamp);
            uniswapRouter.swapExactETHForTokens{value: address(this).balance}(1, path3, address(this), block.timestamp);
        }
        
        /**
         * Then take the 200,000 usdc and exchange for ETH,
         * Then exchange the ETH for HEX,
         * Then exchange the HEX back to USDC.
        */
        address[] memory path4 = new address[](2);
        path4[0] = usdc;
        path4[1] = eth;
        uniswapRouter.swapExactTokensForETH(2 * 1e5 * 1e18, 1, path4, address(this), block.timestamp);
        address[] memory path5 = new address[](2);
        path5[0] = eth;
        path5[1] = hex;
        uniswapRouter.swapExactETHForTokens{value: address(this).balance}(1, path5, address(this), block.timestamp);
        address[] memory path6 = new address[](3);
        path6[0] = hex;
        path6[1] = eth;
        path6[2] = usdc;
        hexAmount1 = IERC20(hex).balanceOf(address(this));
        uniswapRouter.swapExactTokensForTokens(hexAmount1, 1, path6, address(this), block.timestamp); 
        

        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));
    }

    /**
        Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan() public onlyOwner { // usdc loan address
        bytes memory data = "";
        uint amount = 2.5 * 1e5 * 1e18; //

        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), usdc, amount, data);
    }
}
