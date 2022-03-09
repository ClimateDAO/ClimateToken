// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/security/Pausable.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Climate is ERC20, Pausable, Ownable, ERC20Permit, ERC20Votes {
    using SafeMath for uint256;

    bool private isTransferableFlag = false;

    //Tx fees variables
    uint256 public _initialTaxFee = 15; 
    uint256 public _expiry = 15780000;
    mapping (address => uint256) internal _lastTokenTransferTime;
    mapping (address => bool) internal isExcludedFromFee;

    //opsClimateDAOWallet for purposes of tx fee
    address opsClimateDAOWallet = 0x20c7F2a24f33cF4F02D2D185e49aC7B1C975d37f;
    address treasuryClimateDAOWallet = 0x20c7F2a24f33cF4F02D2D185e49aC7B1C975d37f;
    
    constructor() ERC20("Climate", "CLIMATE") ERC20Permit("Climate") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[opsClimateDAOWallet] = true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function _calculateTaxFee(uint256 amount) internal view returns (uint256 feeTaken, uint256 transferAmount) {
        
        /**
         *  The actual calculation is: 
         *  
         *  initialFee = amount / initialTax 
         *  taxFraction = (expiry - timeSince) / expiry
         *  actualFee = initialFee * taxFraction 
         *  
         *  To avoid decimal issues, it's best to multiply all the numerators first, then denominators
         *  
         *  feeNumerator = amount * (expiry - timeSince) 
         *  feeDenominator = expiry * initialTax            // Requires a non-zero initialTaxFee 
         *  actualFee = feeNumerator / feeDenominator 
         *  
         */

        require(amount > 0, "Must transfer a non-zero amount"); 
        
        if(isExcludedFromFee[msg.sender] || _initialTaxFee == 0) {
            return (0, amount); 
        }

        uint256 lastTransferTime = _lastTokenTransferTime[msg.sender]; 
        uint256 timeSince = block.timestamp - lastTransferTime; 

        if(timeSince >= _expiry) {
            return (0, amount); 
        }

        uint256 feeNumerator = amount.mul(_initialTaxFee).mul(_expiry.sub(timeSince)); 
        uint256 feeDenominator = _expiry.mul(100);  
        feeTaken = feeNumerator.div(feeDenominator); 
        transferAmount = amount.sub(feeTaken); 

        return (feeTaken, transferAmount); 

    }

    function _distributeFees(uint256 fees) internal pure returns (uint256 climateDaoOpsPortion, uint256 climateDaoTreasuryPortion){

        //Fees as described in the Whitepaper, these add up to 100
        uint256 climateDaoOpsPortion = fees.div(2);
        uint256 climateDaoTreasuryPortion = fees.div(2);

        return (climateDaoOpsPortion, climateDaoTreasuryPortion);
    }

    function transfer(address recipient, uint256 amount) public 
    virtual 
    override(ERC20) 
    returns (bool)
    {
        address owner = owner();
        // If not transfer fee just check for the transferable flag
        if(_initialTaxFee == 0) {
            //if owner do normal send, if not check if it is transferable
            if(msg.sender == owner) {
                super.transfer(recipient, amount);
            }
            else {
                require(isTransferableFlag, "The token is not yet transferable");
                super.transfer(recipient, amount);
            }
        }
        // There is a transfer fee so if they are not the contract owner or on the excluded list, calculate the fee
        else {
            require(_initialTaxFee != 0, "The Tx fee is 0 there is no fee to calculate");
            if(msg.sender == owner) {
                super.transfer(recipient, amount);
            }
            else {
                require(isTransferableFlag, "The token is not yet transferable");
                if(isExcludedFromFee[msg.sender]) {
                    super.transfer(recipient, amount);
                }
                else {
                    (uint256 feeTaken, uint256 transferAmount) = _calculateTaxFee(amount);
                    (uint256 climateDaoOpsPortion, uint256 climateDaoTreasuryPortion) = _distributeFees(feeTaken);
                    super.transfer(recipient, transferAmount);
                    super.transfer(opsClimateDAOWallet, climateDaoOpsPortion);
                    super.transfer(treasuryClimateDAOWallet, climateDaoTreasuryPortion);                    
                }
            }
        }
        _lastTokenTransferTime[recipient] = block.timestamp;
        return true;
        
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override(ERC20) returns (bool) {
        address owner = owner();
        // If not transfer fee just check for the transferable flag
        if(_initialTaxFee == 0) {
            //if owner do normal send, if not check if it is transferable
            if(msg.sender == owner) {
                super.transferFrom(from, to, amount);
            }
            else {
                require(isTransferableFlag, "The token is not yet transferable");
                super.transferFrom(from, to, amount);
            }
        }
        // There is a transfer fee so if they are not the contract owner or on the excluded list, calculate the fee
        else {
            require(_initialTaxFee != 0, "The Tx fee is 0 there is no fee to calculate");
            if(msg.sender == owner) {
                super.transferFrom(from, to, amount);
            }
            else {
                require(isTransferableFlag, "The token is not yet transferable");
                if(isExcludedFromFee[msg.sender]) {
                    super.transferFrom(from, to, amount);
                }
                else {
                    (uint256 feeTaken, uint256 transferAmount) = _calculateTaxFee(amount);
                    (uint256 climateDaoOpsPortion, uint256 climateDaoTreasuryPortion) = _distributeFees(feeTaken);
                    super.transferFrom(from, to, transferAmount);
                    super.transferFrom(from, opsClimateDAOWallet, climateDaoOpsPortion);
                    super.transferFrom(from, treasuryClimateDAOWallet, climateDaoTreasuryPortion);
                }
            }
        }
        _lastTokenTransferTime[to] = block.timestamp;
        return true;
    }

    function makeTransferable() public onlyOwner {
        isTransferableFlag = true;
    }

    function makeNonTransferable() public onlyOwner {
        isTransferableFlag = false;
    }

    function changeTransferFee(uint256 newFee) public onlyOwner {
        require(newFee <= 100, "The transfer fee cannot be more than the amount being transferred. 100 is the largest possiblle value");
        _initialTaxFee = newFee;
    }

    function addFeeExclusion(address accountToExclude) public onlyOwner {
        isExcludedFromFee[accountToExclude] = true;
    }

    function setNewWalletAddress(uint8 wallet0or1, address newAddress) public onlyOwner {
        require(wallet0or1 == 0 || wallet0or1 == 1, "To change a ClimateDAO wallet address the value must be 0 for opsWallet or 1 for treasuryWallet");
        if(wallet0or1 == 0) {
            opsClimateDAOWallet = newAddress;
        }
        else if(wallet0or1 == 1) {
            treasuryClimateDAOWallet = newAddress;
        }
    }
}
