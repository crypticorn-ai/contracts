//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract CrypticornSimple is ERC20, Ownable, ERC20Burnable {
    uint256 public constant TOTAL_SUPPLY = 100000000 * 10**18; // 100M tokens
    
    address public marketingWallet;
    bool public tradingEnabled = false;
    
    // Simplified tax structure
    uint256 public buyTax = 200; // 2%
    uint256 public sellTax = 500; // 5%
    uint256 public constant TAX_DENOMINATOR = 10000;
    
    mapping(address => bool) public exemptFromTax;
    
    event TradingEnabled();
    event TaxUpdated(uint256 buyTax, uint256 sellTax);
    
    constructor(
        address _marketingWallet,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero address");
        
        marketingWallet = _marketingWallet;
        
        // Mint all tokens to deployer initially
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Set tax exemptions
        exemptFromTax[msg.sender] = true;
        exemptFromTax[address(this)] = true;
        exemptFromTax[_marketingWallet] = true;
        exemptFromTax[address(0)] = true;
        
        emit TradingEnabled();
    }
    
    // ========================
    // ERC20 Functions (explicitly declared for clarity)
    // ========================
    
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        return super.approve(spender, amount);
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return super.allowance(owner, spender);
    }
    
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }
    
    function name() public view override returns (string memory) {
        return super.name();
    }
    
    function symbol() public view override returns (string memory) {
        return super.symbol();
    }
    
    function decimals() public view override returns (uint8) {
        return super.decimals();
    }
    
    // ========================
    // Admin Functions
    // ========================
    
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
    }
    
    function setTaxes(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        require(_buyTax <= 1000, "Buy tax cannot exceed 10%"); // Max 10%
        require(_sellTax <= 1000, "Sell tax cannot exceed 10%"); // Max 10%
        
        buyTax = _buyTax;
        sellTax = _sellTax;
        
        emit TaxUpdated(_buyTax, _sellTax);
    }
    
    function setExemptFromTax(address account, bool exempt) external onlyOwner {
        exemptFromTax[account] = exempt;
    }
    
    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero address");
        marketingWallet = _marketingWallet;
        exemptFromTax[_marketingWallet] = true;
    }
    
    // ========================
    // Internal Functions
    // ========================
    
    function _update(address from, address to, uint256 amount) internal override {
        // Apply taxes only if trading is enabled and both addresses are not exempt
        if (tradingEnabled && !exemptFromTax[from] && !exemptFromTax[to] && from != address(0) && to != address(0)) {
            uint256 taxAmount = 0;
            
            // Simple tax logic - you can enhance this later
            if (amount > 0) {
                taxAmount = (amount * buyTax) / TAX_DENOMINATOR; // Using buyTax as default
                
                if (taxAmount > 0) {
                    super._update(from, marketingWallet, taxAmount);
                    amount = amount - taxAmount;
                }
            }
        }
        
        super._update(from, to, amount);
    }
    
    // ========================
    // Emergency Functions
    // ========================
    
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot rescue own tokens");
        IERC20(token).transfer(to, amount);
    }
    
    function rescueBNB(address payable to, uint256 amount) external onlyOwner {
        to.transfer(amount);
    }
    
    receive() external payable {}
} 