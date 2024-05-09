pragma solidity ^0.8.0;

contract DeflatingERC20 {
    string public constant name = "Deflating Test Token";
    string public constant symbol = "DTT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => uint256) public nonces;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function test() public { /* to remove from coverage */ }

    constructor(uint256 _totalSupply) {       
        _mint(msg.sender, _totalSupply);
    }

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + (value);
        balanceOf[to] = balanceOf[to] + (value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - (value);
        totalSupply = totalSupply - (value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) private {
        uint256 burnAmount = value / 100;
        _burn(from, burnAmount);
        uint256 transferAmount = value - (burnAmount);
        balanceOf[from] = balanceOf[from] - (transferAmount);
        balanceOf[to] = balanceOf[to] + (transferAmount);
        emit Transfer(from, to, transferAmount);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender] - (value);
        }
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }
}
