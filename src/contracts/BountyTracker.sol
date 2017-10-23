pragma solidity ^0.4.4;

import "./SafeMath.sol";
import "./HumanStandardToken.sol";

contract BountyTracker is SafeMath {

    //==========================================
    // TO-DO-TASKS
    //==========================================

    /*  SETTERS
        - tag ACCEPTED github pull requests to token transfers
    */

    /*
    Need to Fix shareOf function.
    */

    //==========================================
    // VARIABLES
    //==========================================

    event ChangeOwner (address _oldOwner, address _newOwner);
    event ManagerAdded (address _newManager);
    event ManagerDeleted (address _oldManager);
    event SubmitWork (address _bountyHunter, uint256 _tokenAmount, bytes32 _pullRequestID);
    event AcceptWork (address _projectManager, address _bountyHunter, uint256 _amount);
    event BountyFunded (address _funder, uint256 _amount);
    event BountyLocked (address _locker, uint256 _lockBlockTime);
    event BountyUnlocked (address _unlocker, uint256 _unlockBlockTime);
    event BountyCLaimed (address _bountyHunter, uint256 _tokenAmount, uint256 _etherAmount);

    address public tokenContractAddress;
    address public bountyCreator;
    mapping (address => bool) bountyManagers;

    uint256 public lockBlockNumber;
    uint256 public lockPayAmount;
    uint256 public unlockBlockNumber;

    HumanStandardToken token;

    enum requestState {
        Inactive,
        Locked,
        Unlocked
    }

    requestState public bountyStatus;

    struct pullRequestStruct {
        address bountyHunter;
        uint256 tokenBountyAmount;
    }

    mapping (bytes32 => pullRequestStruct) public pullRequests;

    //==========================================
    // MODIFIERS
    //==========================================

    modifier onlyBountyCreator {
        require(msg.sender == bountyCreator);
        _;
    }

    modifier onlyBountyManagers () {
        require(bountyManagers[msg.sender] == true);
        _;
    }

    modifier checkClaimAllowable () {
        require(bountyStatus == requestState.Unlocked && unlockBlockNumber > lockBlockNumber);
        _;
    }

    modifier onlyBountySubmitter (bytes32 _pullRequestID) {
        require(msg.sender == pullRequests[_pullRequestID].bountyHunter);
        _;
    }

    //==========================================
    // CONSTRUCTOR
    //==========================================

    function BountyTracker (address _tokenContract) {
        bountyCreator = msg.sender;
        bountyManagers[msg.sender] = true;
        token = HumanStandardToken(_tokenContract);
        tokenContractAddress = _tokenContract;
        bountyStatus = requestState.Inactive;
    }

    //==========================================
    // GETTERS
    //==========================================

    function bountyValue () public constant returns (uint currentBounty) {
        return tokenContractAddress.balance;
    }

    function shareOf (uint256 _tokenAmount) constant returns (uint256 _shareOf) {
        require(token.balanceOf(msg.sender) >= _tokenAmount);
        return div(_tokenAmount, token.totalSupply());
    }

    function isBountyManager () constant returns (bool isTrue) {
        return bountyManagers[msg.sender];
    }

    function isBountyCreator () constant returns (bool isTrue) {
        if (bountyCreator != msg.sender) return false;
    }

    //==========================================
    // SETTERS
    //==========================================

    function submitBounty (uint256 _tokenAmount, bytes32 _pullRequestID) returns (bool success) {
        pullRequests[_pullRequestID] = pullRequestStruct ({
            bountyHunter: msg.sender,
            tokenBountyAmount: _tokenAmount
        });
        SubmitWork(msg.sender, _tokenAmount, _pullRequestID);
        return true;
    }

    function acceptWork (address _bountyHunter, uint256 _amount) onlyBountyManagers returns (bool success) {
        require(token.transfer(_bountyHunter, _amount));
        bountyStatus = requestState.Locked;
        AcceptWork(msg.sender, _bountyHunter, _amount);
        return true;
    }

    function claimBounty (uint256 _tokenAmount) checkClaimAllowable returns (bool success) {
        uint256 sendBalance = mul(this.balance, shareOf(_tokenAmount));
        token.approve(msg.sender, bountyCreator, _tokenAmount);
        token.transferFrom(msg.sender, bountyCreator, _tokenAmount);
        BountyCLaimed(msg.sender, _tokenAmount, sendBalance);
        require(msg.sender.send(sendBalance));
        return true;
    }

    function lockBounty () public onlyBountyManagers returns (bool success) {
        bountyStatus = requestState.Locked;
        lockBlockNumber = block.number;
        BountyLocked(msg.sender, lockBlockNumber);
        return true;
    }

    function unlockBounty () public onlyBountyCreator returns (bool success) {
        require(bountyStatus != requestState.Inactive);
        bountyStatus = requestState.Unlocked;
        unlockBlockNumber = block.number;
        BountyUnlocked(msg.sender, unlockBlockNumber);
        return true;
    }

    function changeBountyCreator (address _newBountyCreator) onlyBountyCreator returns (bool success) {
        bountyCreator = _newBountyCreator;
        ChangeOwner(bountyCreator, _newBountyCreator);
        return true;
    }

    function addManager (address _newManager) onlyBountyCreator returns (bool success) {
        bountyManagers[_newManager] = true;
        ManagerAdded(_newManager);
        return true;
    }

    function delManager (address _oldManager) onlyBountyCreator returns (bool success) {
        bountyManagers[_oldManager] = false;
        ManagerDeleted(_oldManager);
        return true;
    }

    //==========================================
    // MISCELLANEOUS
    //==========================================

    function () payable {
        require(bountyStatus != requestState.Inactive);
        BountyFunded(msg.sender, msg.value);
    }

    //==========================================
    // Work-In-Progress
    //==========================================
    //Document expected API inputs / outputs
}
