//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface ISurebuy{

    struct Entity {
        string pan;
        string name;
    }

    struct Request {
        uint256 id;
        address vendor;
        address manufacturer;
        bool granted;
    }

    function isAVendor(address _addr) external view returns(bool);

    function isAManufacturer(address _addr) external view returns(bool);

    function isAttested(address _ven, address _man) external view returns(bool);

    function getRequest(uint256 _id) external view returns(Request memory);

    function getApprovedManufacturers(address _ven) external view returns(address[] memory);

    function getApprovedVendors(address _man) external view returns(address[] memory);

    function getEntity(address _addr) external view returns(Entity memory);
}