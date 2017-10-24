pragma solidity ^0.4.4;

import "./SafeMath.sol";
import "./HumanStandardToken.sol";

contract BountyTracker is SafeMath {

    //==========================================
    // TO-DO-TASKS
    //==========================================

    /*
    Need to make sure Function "shareOf" is working properly to identify token percentage out of total supply.
    */

    //==========================================
    // VARIABLES
    //==========================================
//  Event logs for callback functions
    event ChangeOwner (address _oldOwner, address _newOwner);
    event ManagerAdded (address _newManager);
    event ManagerDeleted (address _oldManager);
    event SubmitWork (address _bountyHunter, uint256 _tokenAmount, bytes32 _pullRequestID);
    event AcceptWork (address _projectManager, address _bountyHunter, uint256 _amount);
    event BountyFunded (address _funder, uint256 _amount);
    event BountyLocked (address _locker, uint256 _lockBlockTime);
    event BountyUnlocked (address _unlocker, uint256 _unlockBlockTime);
    event BountyCLaimed (address _bountyHunter, uint256 _tokenAmount, uint256 _etherAmount);

//  Address management for Project
    address public ProjectcontractAddress;
    address public ProjectCreator;
    mapping (address => bool) ProjectManagers;

//  Locking with block numbers
    uint256 public lockBlockNumber;
    uint256 public unlockBlockNumber;

//  Create ERC-20 Token
    HumanStandardToken token;

//  Bounty Status States
    enum bountyState {
        Inactive,
        Locked,
        Unlocked
    }
    bountyState public bountyStatus;

//  Pull Request Data Structures
    struct pullRequestStruct {
        address bountyHunter;
        uint256 bountyTokenAmount;
    }
    mapping (bytes32 => pullRequestStruct) public pullRequests;

    //==========================================
    // MODIFIERS
    //==========================================
//  Only permit ProjectCreator to perform function
    modifier onlyProjectCreator {
        require(msg.sender == ProjectCreator);
        _;
    }

//  Only permit ProjectManagers to perform function
    modifier onlyProjectManagers () {
        require(ProjectManagers[msg.sender] == true);
        _;
    }

//  Only permit function if both bounty lock systems are open
    modifier checkClaimAllowable () {
        require(bountyStatus == bountyState.Unlocked && unlockBlockNumber > lockBlockNumber);
        _;
    }

//  Only permit bountyHunter to perform function
//  @Input_Dev      _pullRequestID: ID tag for Pull Requests
    modifier onlyBountySubmitter (bytes32 _pullRequestID) {
        require(msg.sender == pullRequests[_pullRequestID].bountyHunter);
        _;
    }

    //==========================================
    // CONSTRUCTOR
    //==========================================
//  Initialize Project starting states
//  Address that pays to deploy this smart contract is ProjectCreator
//  "bountyStatus" set to "Inactive" before any project work is accepted
//  @Input_Dev      _tokenContract: Token contract address is declared up-front
    function BountyTracker (address _tokenContract) {
        ProjectCreator = msg.sender;
        ProjectManagers[msg.sender] = true;
        token = HumanStandardToken(_tokenContract);
        ProjectcontractAddress = _tokenContract;
        bountyStatus = bountyState.Inactive;
    }

    //==========================================
    // GETTERS
    //==========================================
//  Check "ether" balance of Project smart contract address
//  @Output_Dev     Output value in Wei (1 ETH = 1 000 000 000 000 000 000 Wei)
    function bountyValue () public constant returns (uint currentBounty) {
        return ProjectcontractAddress.balance;
    }

//  Check Percentage token share owned by "msg.sender"
//  @Input_Dev      Token amount being checked for "shareOf"
//  @Output_Dev     Return "x"% out of 100% of tokens
    function shareOf (uint256 _tokenAmount) constant returns (uint256 _shareOf) {
        require(token.balanceOf(msg.sender) >= _tokenAmount);
        return div(_tokenAmount, token.totalSupply());
    }

//  Check if address is a ProjectManager
//  @Output_Dev     Return "true" or "false" for "msg.sender" address
    function isBountyManager () constant returns (bool isTrue) {
        return ProjectManagers[msg.sender];
    }

//  Check if address is the ProjectCreator
//  @Output_Dev     Return "true" or "false" for "msg.sender" address
    function isProjectCreator () constant returns (bool isTrue) {
        if (ProjectCreator != msg.sender) return false;
    }

    //==========================================
    // SETTERS
    //==========================================
//  Submit Pull Request with Bounty Amount
//  @Input_Dev      _tokenAmount: Amount of token bounty requested for Pull Request
//  @Input_Dev      _pullRequestID: ID tag for Pull Requests
//  @Output_Dev     Return "true" if Pull Request & token bounty are saved
    function submitBounty (uint256 _tokenAmount, bytes32 _pullRequestID) returns (bool success) {
        pullRequests[_pullRequestID] = pullRequestStruct ({
            bountyHunter: msg.sender,
            bountyTokenAmount: _tokenAmount
        });
        SubmitWork(msg.sender, _tokenAmount, _pullRequestID);
        return true;
    }

//  Accept Pull Request with Bounty Amount
//  @Modifier_Dev   onlyProjectManagers: Only allow ProjectManagers to accept work
//  @Input_Dev      _bountyHunter: Address of bounty submitter
//  @Input_Dev      _amount: Token bounty amount for work submitted
//  @Output_Dev     Return "true" when token bounty is transferred and bountyStatus is locked
    function acceptWork (address _bountyHunter, uint256 _amount) onlyProjectManagers returns (bool success) {
        require(token.transfer(_bountyHunter, _amount));
        bountyStatus = bountyState.Locked;
        AcceptWork(msg.sender, _bountyHunter, _amount);
        return true;
    }

//  Claim ethers from Project Bounty
//  @Modifier_Dev   checkClaimAllowable: check "bountyStatus" and BlockNumber locks
//  @Input_Dev      _tokenAmount: Amount of tokens being claimed for ethers
//  @Output_Dev     Send the % portion of ethers to "bountyHunter" address
//  @Output_Dev     Transfer project bounty tokens from "bountyHunter" address
    function claimBounty (uint256 _tokenAmount) checkClaimAllowable returns (bool success) {
        uint256 sendBalance = mul(this.balance, shareOf(_tokenAmount));
        token.approve(msg.sender, ProjectCreator, _tokenAmount);
        token.transferFrom(msg.sender, ProjectCreator, _tokenAmount);
        BountyCLaimed(msg.sender, _tokenAmount, sendBalance);
        require(msg.sender.send(sendBalance));
        return true;
    }

//  Lock bounty with "bountyStatus" and BlockNumber
//  @Modifier_Dev   onlyProjectManagers: Only allow ProjectManagers to lock project bounty
//  @Output_Dev     Lock up bountyState and record "lockBlockNumber"
    function lockBounty () public onlyProjectManagers returns (bool success) {
        bountyStatus = bountyState.Locked;
        lockBlockNumber = block.number;
        BountyLocked(msg.sender, lockBlockNumber);
        return true;
    }

//  Unlockock bounty with "bountyStatus" and BlockNumber
//  @Modifier_Dev   onlyProjectCreator: Only allow ProjectCreator to unlock project bounty
//  @Output_Dev     Unlock bountyState and record "unlockBlockNumber"
    function unlockBounty () public onlyProjectCreator returns (bool success) {
        require(bountyStatus != bountyState.Inactive);
        bountyStatus = bountyState.Unlocked;
        unlockBlockNumber = block.number;
        BountyUnlocked(msg.sender, unlockBlockNumber);
        return true;
    }

//  Change ProjectCreator address
//  @Modifier_Dev   onlyProjectCreator: Only allow ProjectCreator to set new ProjectCreator
//  @Output_Dev     Return "true" when new address is set as ProjectCreator
    function changeProjectCreator (address _newProjectCreator) onlyProjectCreator returns (bool success) {
        require(_newProjectCreator != ProjectCreator);
        ProjectCreator = _newProjectCreator;
        ChangeOwner(ProjectCreator, _newProjectCreator);
        return true;
    }

//  Add new ProjectManager address
//  @Modifier_Dev   onlyProjectCreator: Only allow ProjectCreator to add new ProjectManager
//  @Output_Dev     Return "true" when new address is set as ProjectManager
    function addManager (address _newManager) onlyProjectCreator returns (bool success) {
        ProjectManagers[_newManager] = true;
        ManagerAdded(_newManager);
        return true;
    }
//  Delete old ProjectManager address
//  @Modifier_Dev   onlyProjectCreator: Only allow ProjectCreator to delete old ProjectManager
//  @Output_Dev     Return "true" when new address is set as ProjectManager
    function delManager (address _oldManager) onlyProjectCreator returns (bool success) {
        ProjectManagers[_oldManager] = false;
        ManagerDeleted(_oldManager);
        return true;
    }

    //==========================================
    // Fallback Function
    //==========================================
//  "Payable" Fallback function for 3rd party funding of project with "ethers"
//  @Output_Dev     Project must have accepted work before "ethers" are allowed be funded
//  @Output_Dev     Signal Project funder & "ether" amount funded
    function () payable {
        require(bountyStatus != bountyState.Inactive);
        BountyFunded(msg.sender, msg.value);
    }
}
