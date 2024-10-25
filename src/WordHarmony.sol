// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC20Base.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

contract WordHarmonyToken is ERC20Base, PermissionsEnumerable {
    struct PlayerStats {
        uint256 totalScore;
        uint256 levelsCompleted;
        uint256 lastPlayTimestamp;
        uint256 dailyPlays;
    }
    
    struct Level {
        string[] solutions;
        uint256 reward;
        uint256 minScore;
        bool isActive;
    }
    
    mapping(address => PlayerStats) public playerStats;
    mapping(uint256 => Level) public levels;
    mapping(address => mapping(uint256 => bool)) public completedLevels;
    
    uint256 public currentLevelCount;
    uint256 public constant DAILY_PLAY_LIMIT = 20;
    uint256 public constant DAILY_RESET_TIME = 24 hours;
    
    event LevelCompleted(address indexed player, uint256 levelId, uint256 score);
    event DailyLimitReset(address indexed player);
    
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20Base(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function addLevel(
        string[] memory solutions,
        uint256 reward,
        uint256 minScore
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        levels[currentLevelCount] = Level({
            solutions: solutions,
            reward: reward,
            minScore: minScore,
            isActive: true
        });
        currentLevelCount++;
    }
    
    function checkDailyLimit(address player) internal {
        if (block.timestamp >= playerStats[player].lastPlayTimestamp + DAILY_RESET_TIME) {
            playerStats[player].dailyPlays = 0;
            playerStats[player].lastPlayTimestamp = block.timestamp;
            emit DailyLimitReset(player);
        }
        require(playerStats[player].dailyPlays < DAILY_PLAY_LIMIT, "Daily play limit reached");
    }
    
    function submitSolution(
        uint256 levelId,
        string memory solution,
        uint256 score
    ) external {
        require(levelId < currentLevelCount, "Level does not exist");
        require(levels[levelId].isActive, "Level is not active");
        require(!completedLevels[msg.sender][levelId], "Level already completed");
        require(score >= levels[levelId].minScore, "Score too low");
        
        checkDailyLimit(msg.sender);
        
        bool validSolution = false;
        for(uint i = 0; i < levels[levelId].solutions.length; i++) {
            if(keccak256(abi.encodePacked(solution)) == keccak256(abi.encodePacked(levels[levelId].solutions[i]))) {
                validSolution = true;
                break;
            }
        }
        require(validSolution, "Invalid solution");
        
        // Update player stats
        playerStats[msg.sender].totalScore += score;
        playerStats[msg.sender].levelsCompleted++;
        playerStats[msg.sender].dailyPlays++;
        completedLevels[msg.sender][levelId] = true;
        
        // Mint rewards
        _mint(msg.sender, levels[levelId].reward);
        
        emit LevelCompleted(msg.sender, levelId, score);
    }
    
    function getPlayerStats(address player) external view returns (PlayerStats memory) {
        return playerStats[player];
    }
}