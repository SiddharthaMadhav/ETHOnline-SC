//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISP} from "@ethsign/sign-protocol-evm/src/interfaces/ISP.sol";
import {Attestation} from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import {DataLocation} from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";

contract Surebuy {
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

    ISP public spInstance;
    uint64 public schemaId;

    uint256 private _requestCounter = 0;

    mapping(address => bool) isManufacturer;
    mapping(address => bool) isVendor;
    mapping(uint256 => Request) idToRequest;
    mapping(address => Entity) addressToEntity;
    mapping(address => uint256[]) vendorToRequestIds;
    mapping(address => uint256[]) manufacturerToRequestIds;
    mapping(address => mapping(address => bool)) vendorToManufacturer;
    mapping(address => mapping(address => bool)) requested;
    mapping(address => address[]) approvedVendorsToManufacturer;
    mapping(address => address[]) approvedManufacturerToVendor;

    error SureBuy_AlreadyRegistered();
    error SureBuy_NotAllowed();

    constructor() {}

    function setSPInstance(address instance) external  {
        spInstance = ISP(instance);
    }

    function setSchemaID(uint64 schemaId_) external  {
        schemaId = schemaId_;
    }

    function registerAsManufacturer(
        string memory _name,
        string memory _pan
    ) public {
        if (isManufacturer[msg.sender] || isVendor[msg.sender]) {
            revert SureBuy_AlreadyRegistered();
        }
        addressToEntity[msg.sender] = Entity(_pan, _name);
        isManufacturer[msg.sender] = true;
    }

    function registerAsVendor(string memory _name, string memory _pan) public {
        if (isManufacturer[msg.sender] || isVendor[msg.sender]) {
            revert SureBuy_AlreadyRegistered();
        }
        addressToEntity[msg.sender] = Entity(_pan, _name);
        isVendor[msg.sender] = true;
    }

    function sendRequest(address _man) public {
        if (
            !isVendor[msg.sender] ||
            isManufacturer[msg.sender] ||
            requested[msg.sender][_man] ||
            !isManufacturer[_man] ||
            isVendor[_man]
        ) {
            revert();
        }
        Request memory newRequest = Request(
            _requestCounter,
            msg.sender,
            _man,
            false
        );
        idToRequest[_requestCounter] = newRequest;
        vendorToRequestIds[msg.sender].push(_requestCounter);
        manufacturerToRequestIds[_man].push(_requestCounter);
        requested[msg.sender][_man] = true;
        _requestCounter += 1;
    }

    function confirmRequest(uint256 requestId) external returns (uint64) {
        if (
            requestId >= _requestCounter ||
            !isManufacturer[msg.sender] ||
            isVendor[msg.sender]
        ) {
            revert SureBuy_NotAllowed();
        }
        Request memory temp = idToRequest[requestId];
        if (
            !isVendor[temp.vendor] ||
            !isManufacturer[temp.manufacturer] ||
            temp.granted
        ) {
            revert SureBuy_NotAllowed();
        }
        uint256 index1;
        uint256 n1 = manufacturerToRequestIds[msg.sender].length;
        bool flag = false;
        for (uint256 i = 0; i < n1; i++) {
            if (requestId == manufacturerToRequestIds[msg.sender][i]) {
                index1 = i;
                flag = true;
                break;
            }
        }
        if (!flag) {
            revert SureBuy_NotAllowed();
        }
        manufacturerToRequestIds[msg.sender][index1] = manufacturerToRequestIds[
            msg.sender
        ][n1 - 1];
        manufacturerToRequestIds[msg.sender].pop();
        uint256 index2;
        uint256 n2 = vendorToRequestIds[temp.vendor].length;
        for (uint256 i = 0; i < n2; i++) {
            if (requestId == vendorToRequestIds[temp.vendor][i]) {
                index2 = i;
                break;
            }
        }
        vendorToRequestIds[temp.vendor][index2] = vendorToRequestIds[
            temp.vendor
        ][n2 - 1];
        vendorToRequestIds[temp.vendor].pop();

        bytes memory data = abi.encode(
            temp.vendor,
            addressToEntity[temp.vendor].name,
            addressToEntity[temp.vendor].pan
        );
        bytes[] memory recipients = new bytes[](1);
        recipients[0] = abi.encode(temp.vendor);

        vendorToManufacturer[temp.vendor][temp.manufacturer] = true;

        approvedVendorsToManufacturer[temp.vendor].push(temp.manufacturer);
        approvedManufacturerToVendor[temp.manufacturer].push(temp.vendor);

        idToRequest[requestId].granted = true;

        Attestation memory a = Attestation({
            schemaId: schemaId,
            linkedAttestationId: 0,
            attestTimestamp: 0,
            revokeTimestamp: 0,
            attester: address(this),
            validUntil: 0,
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: recipients,
            data: data
        });
        uint64 attestationId = spInstance.attest(a, "", "", "");

        temp.granted = true;

        return 0;
    }

    function declineRequest(uint256 requestId) external {
        if (
            requestId >= _requestCounter ||
            !isManufacturer[msg.sender] ||
            isVendor[msg.sender]
        ) {
            revert();
        }
        Request memory temp = idToRequest[requestId];
        if (
            !isVendor[temp.vendor] ||
            !isManufacturer[temp.manufacturer] ||
            temp.granted
        ) {
            revert();
        }
        idToRequest[requestId].granted = false;
        uint256 index1;
        uint256 n1 = manufacturerToRequestIds[msg.sender].length;
        bool flag = false;
        for (uint256 i = 0; i < n1; i++) {
            if (requestId == manufacturerToRequestIds[msg.sender][i]) {
                index1 = i;
                flag = true;
                break;
            }
        }
        if (!flag) {
            revert();
        }
        manufacturerToRequestIds[msg.sender][index1] = manufacturerToRequestIds[
            msg.sender
        ][n1 - 1];
        manufacturerToRequestIds[msg.sender].pop();
        uint256 index2;
        uint256 n2 = vendorToRequestIds[temp.vendor].length;
        for (uint256 i = 0; i < n2; i++) {
            if (requestId == vendorToRequestIds[temp.vendor][i]) {
                index2 = i;
                break;
            }
        }
        vendorToRequestIds[temp.vendor][index2] = vendorToRequestIds[
            temp.vendor
        ][n2 - 1];
        vendorToRequestIds[temp.vendor].pop();
        requested[temp.vendor][temp.manufacturer] = false;
    }

    function getRequests() external view returns (Request[] memory) {
        if (isVendor[msg.sender]) {
            uint256 size = vendorToRequestIds[msg.sender].length;
            Request[] memory temp = new Request[](size);
            for (uint i = 0; i < size; i++) {
                temp[i] = (idToRequest[vendorToRequestIds[msg.sender][i]]);
            }
            return temp;
        }else if (isManufacturer[msg.sender]) {
            uint256 size = manufacturerToRequestIds[msg.sender].length;
            Request[] memory temp = new Request[](size);
            for (uint i = 0; i < size; i++) {
                temp[i] = (
                    idToRequest[manufacturerToRequestIds[msg.sender][i]]
                );
            }
            return temp;
        }else{
            revert();
        }
    }

    function isAVendor(address _addr) external view returns(bool){
        return isVendor[_addr];
    }

    function isAManufacturer(address _addr) external view returns(bool){
        return isManufacturer[_addr];
    }

    function isAttested(address _ven, address _man) external view returns(bool){
        if(!isVendor[_ven] || !isManufacturer[_man]){
            revert();
        }
        return vendorToManufacturer[_ven][_man];
    }

    function getRequest(uint256 _id) external view returns(Request memory){
        if(_id >= _requestCounter){
            revert();
        }
        return idToRequest[_id];
    }

    function getApprovedManufacturers(address _ven) external view returns(address[] memory){
        if(!isVendor[_ven]){
            revert();
        }
        return approvedVendorsToManufacturer[_ven];
    }

    function getApprovedVendors(address _man) external view returns(address[] memory){
        if(!isManufacturer[_man]){
            revert();
        }
        return approvedManufacturerToVendor[_man];
    }
    function getEntity(address _addr) external view returns(Entity memory){
        if(isManufacturer[_addr] || isVendor[_addr]){
            return addressToEntity[_addr];
        }else{
            revert();
        }

    }
}
