// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TestERC20
 * @notice A simple ERC20 token for testing and demo purposes on Madari L1
 * @dev Implements the ERC20 standard with mint/burn capabilities for testing
 */
contract TestERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "TestERC20: not owner");
        _;
    }

    /**
     * @notice Creates a new TestERC20 token
     * @param _name Token name (e.g., "Madari Test Token")
     * @param _symbol Token symbol (e.g., "MTT")
     * @param _initialSupply Initial supply to mint to deployer (in whole tokens, not wei)
     */
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;

        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply * 10 ** decimals);
        }
    }

    /**
     * @notice Transfer tokens to a recipient
     * @param to Recipient address
     * @param amount Amount to transfer (in wei)
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /**
     * @notice Approve spender to transfer tokens on your behalf
     * @param spender Address to approve
     * @param amount Amount to approve (in wei)
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another (requires approval)
     * @param from Source address
     * @param to Destination address
     * @param amount Amount to transfer (in wei)
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "TestERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        return _transfer(from, to, amount);
    }

    /**
     * @notice Mint new tokens (owner only)
     * @param to Recipient address
     * @param amount Amount to mint (in wei)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller's balance
     * @param amount Amount to burn (in wei)
     */
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "TestERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    /**
     * @notice Transfer ownership to a new address
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TestERC20: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ Internal Functions ============

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(to != address(0), "TestERC20: transfer to zero address");
        require(balanceOf[from] >= amount, "TestERC20: insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "TestERC20: mint to zero address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
