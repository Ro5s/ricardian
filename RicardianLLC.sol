/*
██████╗ ██╗ ██████╗ █████╗ ██████╗ ██████╗ ██╗ █████╗ ███╗   ██╗
██╔══██╗██║██╔════╝██╔══██╗██╔══██╗██╔══██╗██║██╔══██╗████╗  ██║
██████╔╝██║██║     ███████║██████╔╝██║  ██║██║███████║██╔██╗ ██║
██╔══██╗██║██║     ██╔══██║██╔══██╗██║  ██║██║██╔══██║██║╚██╗██║
██║  ██║██║╚██████╗██║  ██║██║  ██║██████╔╝██║██║  ██║██║ ╚████║
╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
██╗     ██╗      ██████╗                                        
██║     ██║     ██╔════╝                                        
██║     ██║     ██║                                             
██║     ██║     ██║                                             
███████╗███████╗╚██████╗                                        
╚══════╝╚══════╝ ╚═════╝*/
/// Presented by LexDAO LLC
/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.1;

contract RicardianLLC {
    address public governance;
    uint256 public mintFee;
    uint256 public totalSupply;
    string public masterOperatingAgreement;
    string constant public name = "Ricardian LLC, Series";
    string constant public symbol = "LLC";
    
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint256) public salePrice;
    mapping(uint256 => string) public tokenURI;
    mapping(bytes4 => bool) public supportsInterface; // eip-165 
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed approver, address indexed operator, bool approved);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event GovTribute(address indexed caller, uint256 indexed amount, string details);
    event GovUpdateSettings(address indexed governance, uint256 indexed mintFee, string masterOperatingAgreement);
    event GovUpdateTokenURI(uint256 indexed tokenId, string tokenURI);
    event UpdateSale(uint256 indexed price, uint256 indexed tokenId);
    
    constructor(address _governance, string memory _masterOperatingAgreement) {
        governance = _governance; 
        masterOperatingAgreement = _masterOperatingAgreement; 
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
    }
    
    /*****************
    INTERNAL FUNCTIONS
    *****************/
    function _mint(address to) private { 
        totalSupply++;
        uint256 tokenId = totalSupply;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        tokenURI[tokenId] = "";
        emit Transfer(address(0), to, tokenId); 
    }
    
    function _transfer(address from, address to, uint256 tokenId) private {
        require(from == ownerOf[tokenId], "!owner");
        balanceOf[from]--; 
        balanceOf[to]++; 
        getApproved[tokenId] = address(0); // reset approval
        ownerOf[tokenId] = to;
        salePrice[tokenId] = 0; // reset sale price
        emit Transfer(from, to, tokenId); 
    }
    
    /*************
    PUBLIC MINTING
    *************/
    receive() external payable {
        require(msg.value == mintFee, "!mintFee"); // call with ETH fee
        _mint(msg.sender); 
    }
    
    function mintLLC(address to) external payable { 
        require(msg.value == mintFee, "!mintFee"); // call with ETH fee
        (bool success, ) = governance.call{value: msg.value}("");
        require(success, "!ethCall");
        _mint(to);
    }
    
    function mintLLCbatch(address[] calldata to) external payable {
        require(msg.value == mintFee * to.length, "!mintFee"); // call with ETH fee adjusted for batch
        (bool success, ) = governance.call{value: msg.value}("");
        require(success, "!ethCall");
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i]); 
        }
    }
    
    /******************
    PUBLIC BALANCE MGMT
    ******************/
    function approve(address spender, uint256 tokenId) external {
        address owner = ownerOf[tokenId];
        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function transfer(address to, uint256 tokenId) external returns (bool) { // erc20 formatted transfer
        _transfer(msg.sender, to, tokenId);
        return true;
    }
    
    function transferBatch(address[] calldata to, uint256[] calldata tokenId) external {
        require(to.length == tokenId.length, "!to/tokenId");
        for (uint256 i = 0; i < to.length; i++) {
            _transfer(msg.sender, to[i], tokenId[i]);
        }
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == from || getApproved[tokenId] == msg.sender || isApprovedForAll[from][msg.sender], "!owner/spender/operator");
        _transfer(from, to, tokenId);
    }
    
    // ***********
    // PUBLIC SALE
    // ***********
    function purchase(uint256 tokenId) external payable {
        uint256 price = salePrice[tokenId];
        require(price > 0, "!forSale"); // price must be non-zero to be considered 'for sale'
        require(msg.value == price, "!price");
        address owner = ownerOf[tokenId];
        (bool success, ) = owner.call{value: msg.value}("");
        require(success, "!ethCall");
        balanceOf[owner]--; 
        balanceOf[msg.sender]++; 
        getApproved[tokenId] = address(0); // reset approval
        ownerOf[tokenId] = msg.sender;
        salePrice[tokenId] = 0; // reset sale price
        emit Transfer(owner, msg.sender, tokenId); 
    }
    
    function updateSale(uint256 price, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        salePrice[tokenId] = price;
        emit UpdateSale(price, tokenId);
    }
    
    /*******************
    GOVERNANCE FUNCTIONS
    *******************/
    modifier onlyGovernance {
        require(msg.sender == governance, "!governance");
        _;
    }
    
    function govMintLLC(address to) external onlyGovernance { 
        _mint(to);
    }
    
    function govMintLLCbatch(address[] calldata to) external onlyGovernance {
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i]); 
        }
    }
    
    function govTransferFrom(address from, address to, uint256 tokenId) external onlyGovernance {
        _transfer(from, to, tokenId);
    }
    
    function govTransferFromBatch(address[] calldata from, address[] calldata to, uint256[] calldata tokenId) external onlyGovernance {
        require(from.length == to.length && to.length == tokenId.length, "!from/to/tokenId");
        for (uint256 i = 0; i < from.length; i++) {
            _transfer(from[i], to[i], tokenId[i]);
        }
    }
    
    function govTribute(string calldata details) external payable {
        (bool success, ) = governance.call{value: msg.value}("");
        require(success, "!ethCall");
        emit GovTribute(msg.sender, msg.value, details);
    }
    
    function govUpdateSettings(address _governance, uint256 _mintFee, string calldata _masterOperatingAgreement) external onlyGovernance {
        governance = _governance;
        mintFee = _mintFee;
        masterOperatingAgreement = _masterOperatingAgreement;
        emit GovUpdateSettings(_governance, _mintFee, _masterOperatingAgreement);
    }
    
    function govUpdateTokenURI(uint256 tokenId, string calldata _tokenURI) external onlyGovernance {
        require(tokenId <= totalSupply, "!exist");
        tokenURI[tokenId] = _tokenURI;
        emit GovUpdateTokenURI(tokenId, _tokenURI);
    }
    
    function govUpdateTokenURIbatch(uint256[] calldata tokenId, string[] calldata _tokenURI) external onlyGovernance {
        require(tokenId.length == _tokenURI.length, "!tokenId/_tokenURI");
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(tokenId[i] <= totalSupply, "!exist");
            tokenURI[tokenId[i]] = _tokenURI[i];
            emit GovUpdateTokenURI(tokenId[i], _tokenURI[i]);
        }
    }
}
