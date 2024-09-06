//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISurebuy} from "./ISurebuy.sol";

contract SurebuyMP {
    struct Product{
        uint256 id;
        string name;
        string manufacturer;
        address vendorAddress;
        string description;
        uint256 price;
    }

    ISurebuy sbInstance;

    uint256 private _productCounter = 0;
    mapping(uint256 => Product) idToProduct;
    mapping(address => uint256[]) boughtItems;
    mapping(address => uint256[]) saleItems;

    constructor(address _addr){
        sbInstance = ISurebuy(_addr);
    }

    function sellProduct(string memory name, address man, string memory description, uint256 price) public{
        if(!sbInstance.isAttested(msg.sender, man)){
            revert();
        }
        string memory manName = sbInstance.getEntity(man).name;
        Product memory newProduct = Product(_productCounter, name, manName, msg.sender, description, price);
        idToProduct[_productCounter] = newProduct;
        saleItems[msg.sender].push(_productCounter);
        _productCounter += 1;
    }

    function buyProduct(uint256 productId) public payable{
        if(productId >= _productCounter || sbInstance.isAManufacturer(msg.sender) || sbInstance.isAVendor(msg.sender)){
            revert();
        }
        if(msg.value != idToProduct[productId].price){
            revert();
        }
        payable(idToProduct[productId].vendorAddress).transfer(idToProduct[productId].price);
        boughtItems[msg.sender].push(productId);
    }

    function fetchBoughtProducts() public view returns(Product[] memory){
        uint size = boughtItems[msg.sender].length;
        Product[] memory temp = new Product[](size);
        for(uint i = 0; i < size; i++){
            temp[i] = (idToProduct[boughtItems[msg.sender][i]]);
        }
        return temp;
    }

    function fetchSoldProducts() public view returns(Product[] memory){
        uint size = saleItems[msg.sender].length;
        Product[] memory temp = new Product[](size);
        for(uint i = 0; i < size; i++){
            temp[i] = (idToProduct[saleItems[msg.sender][i]]);
        }
        return temp;
    }


}