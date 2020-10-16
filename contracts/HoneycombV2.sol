// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IHoneyPropDict.sol";

contract HoneycombV2 is Ownable, IERC721Receiver {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
    uint256 amount;     // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt.
    uint earned;        // Earned HONEY.
    bool propEnabled;
    uint256 propTokenId;
  }

  // Info of each pool.
  struct PoolInfo {
    IERC20 lpToken;           // Address of LP token contract.
    uint256 allocPoint;       // How many allocation points assigned to this pool.
    uint256 lastRewardBlock;  // Last block number that HONEYs distribution occurs.
    uint256 accHoneyPerShare; // Accumulated HONEYs per share, times 1e12.
    uint256 totalShares;
  }

  struct BatchInfo {
    uint256 startBlock;
    uint256 endBlock;
    uint256 honeyPerBlock;
    uint256 totalAllocPoint;
    address prop;
    address propDict;
  }

  // Info of each batch
  BatchInfo[] public batchInfo;
  // Info of each pool at specified batch.
  mapping (uint256 => PoolInfo[]) public poolInfo;
  // Info of each user at specified batch and pool
  mapping (uint256 => mapping (uint256 => mapping (address => UserInfo))) public userInfo;

  IERC20 public honeyToken;

  event Deposit(address indexed user, uint256 indexed batch, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed batch, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed batch, uint256 indexed pid, uint256 amount);
  event DepositProp(address indexed user, uint256 indexed batch, uint256 indexed pid, uint256 propTokenId);
  event WithdrawProp(address indexed user, uint256 indexed batch, uint256 indexed pid, uint256 propTokenId);

  constructor (address _honeyToken) public {
    honeyToken = IERC20(_honeyToken);
  }

  function addBatch(uint256 startBlock, uint256 endBlock, uint256 honeyPerBlock, address prop, address propDict) public onlyOwner {
    require(endBlock > startBlock, "endBlock should be larger than startBlock");
    require(endBlock > block.number, "endBlock should be larger than the current block number");
    require(startBlock > block.number, "startBlock should be larger than the current block number");
    
    if (batchInfo.length > 0) {
      uint256 lastEndBlock = batchInfo[batchInfo.length - 1].endBlock;
      require(startBlock >= lastEndBlock, "startBlock should be >= the endBlock of the last batch");
    }

    uint256 senderHoneyBalance = honeyToken.balanceOf(address(msg.sender));
    uint256 requiredHoney = endBlock.sub(startBlock).mul(honeyPerBlock);
    require(senderHoneyBalance >= requiredHoney, "insufficient HONEY for the batch");

    honeyToken.safeTransferFrom(address(msg.sender), address(this), requiredHoney);
    batchInfo.push(BatchInfo({
      startBlock: startBlock,
      endBlock: endBlock,
      honeyPerBlock: honeyPerBlock,
      totalAllocPoint: 0,
      prop: prop,
      propDict: propDict
    }));
  }

  function addPool(uint256 batch, IERC20 lpToken, uint256 multiplier) public onlyOwner {
    require(batch < batchInfo.length, "batch must exist");
    
    BatchInfo storage targetBatch = batchInfo[batch];
    if (targetBatch.startBlock <= block.number && block.number < targetBatch.endBlock) {
      updateAllPools(batch);
    }

    uint256 lastRewardBlock = block.number > targetBatch.startBlock ? block.number : targetBatch.startBlock;
    batchInfo[batch].totalAllocPoint = targetBatch.totalAllocPoint.add(multiplier);
    poolInfo[batch].push(PoolInfo({
      lpToken: lpToken,
      allocPoint: multiplier,
      lastRewardBlock: lastRewardBlock,
      accHoneyPerShare: 0,
      totalShares: 0
    }));
  }

  // Return rewardable block count over the given _from to _to block.
  function getPendingBlocks(uint256 batch, uint256 from, uint256 to) public view returns (uint256) {
    require(batch < batchInfo.length, "batch must exist");   
 
    BatchInfo storage targetBatch = batchInfo[batch];

    if (to < targetBatch.startBlock) {
      return 0;
    }
    
    if (to > targetBatch.endBlock) {
      if (from > targetBatch.endBlock) {
        return 0;
      } else {
        return targetBatch.endBlock.sub(from);
      }
    } else {
      return to.sub(from);
    }
  }

  // View function to see pending HONEYs on frontend.
  function pendingHoney(uint256 batch, uint256 pid, address account) external view returns (uint256) {
    require(batch < batchInfo.length, "batch must exist");   
    require(pid < poolInfo[batch].length, "pool must exist");
    BatchInfo storage targetBatch = batchInfo[batch];

    if (block.number < targetBatch.startBlock) {
      return 0;
    }

    PoolInfo storage pool = poolInfo[batch][pid];
    UserInfo storage user = userInfo[batch][pid][account];
    uint256 accHoneyPerShare = pool.accHoneyPerShare;
    if (block.number > pool.lastRewardBlock && pool.totalShares != 0) {
      uint256 pendingBlocks = getPendingBlocks(batch, pool.lastRewardBlock, block.number);
      uint256 honeyReward = pendingBlocks.mul(targetBatch.honeyPerBlock).mul(pool.allocPoint).div(targetBatch.totalAllocPoint);
      accHoneyPerShare = accHoneyPerShare.add(honeyReward.mul(1e12).div(pool.totalShares));
    }

    uint256 power = 100;
    if (user.propEnabled) {
      IHoneyPropDict propDict = IHoneyPropDict(targetBatch.propDict);
      power = propDict.getMiningMultiplier(user.propTokenId);
    }
    return user.amount.mul(power).div(100).mul(accHoneyPerShare).div(1e12).sub(user.rewardDebt);
  }

  function updateAllPools(uint256 batch) public {
    require(batch < batchInfo.length, "batch must exist");   

    uint256 length = poolInfo[batch].length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(batch, pid);
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 batch, uint256 pid) public {
    require(batch < batchInfo.length, "batch must exist");
    require(pid < poolInfo[batch].length, "pool must exist");

    BatchInfo storage targetBatch = batchInfo[batch];
    PoolInfo storage pool = poolInfo[batch][pid];

    if (block.number < targetBatch.startBlock || block.number <= pool.lastRewardBlock || pool.lastRewardBlock > targetBatch.endBlock) {
      return;
    }
    if (pool.totalShares == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }
    uint256 pendingBlocks = getPendingBlocks(batch, pool.lastRewardBlock, block.number);
    uint256 honeyReward = pendingBlocks.mul(targetBatch.honeyPerBlock).mul(pool.allocPoint).div(targetBatch.totalAllocPoint);
    pool.accHoneyPerShare = pool.accHoneyPerShare.add(honeyReward.mul(1e12).div(pool.totalShares));
    pool.lastRewardBlock = block.number;
  }

  // Deposit LP tokens for HONEY allocation.
  function deposit(uint256 batch, uint256 pid, uint256 amount) public {
    require(batch < batchInfo.length, "batch must exist");
    require(pid < poolInfo[batch].length, "pool must exist");

    BatchInfo storage targetBatch = batchInfo[batch];

    require(block.number < targetBatch.endBlock, "batch ended");

    PoolInfo storage pool = poolInfo[batch][pid];
    UserInfo storage user = userInfo[batch][pid][msg.sender];

    // 1. Update pool.accHoneyPerShare
    updatePool(batch, pid);

    // 2. Transfer pending HONEY to user
    uint256 power = 100;
    if (user.propEnabled) {
      IHoneyPropDict propDict = IHoneyPropDict(targetBatch.propDict);
      power = propDict.getMiningMultiplier(user.propTokenId);
    }
    if (user.amount > 0) {
      uint256 pending = user.amount;
      if (user.propEnabled) {
        pending = pending.mul(power).div(100);
      }
      pending = pending.mul(pool.accHoneyPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        safeHoneyTransfer(batch, pid, msg.sender, pending);
      }
    }

    // 3. Transfer LP Token from user to honeycomb
    if (amount > 0) {
      pool.lpToken.safeTransferFrom(address(msg.sender), address(this), amount);
      user.amount = user.amount.add(amount);
    }

    // 4. Update pool.totalShares & user.rewardDebt
    if (user.propEnabled) {
      pool.totalShares = pool.totalShares.add(amount.mul(power).div(100));
      user.rewardDebt = user.amount.mul(power).div(100).mul(pool.accHoneyPerShare).div(1e12);
    } else {
      pool.totalShares = pool.totalShares.add(amount);
      user.rewardDebt = user.amount.mul(pool.accHoneyPerShare).div(1e12);
    }

    emit Deposit(msg.sender, batch, pid, amount);
  }

  // Withdraw LP tokens.
  function withdraw(uint256 batch, uint256 pid, uint256 amount) public {
    require(batch < batchInfo.length, "batch must exist");
    require(pid < poolInfo[batch].length, "pool must exist");
    UserInfo storage user = userInfo[batch][pid][msg.sender];
    require(user.amount >= amount, "insufficient balance");

    // 1. Update pool.accHoneyPerShare
    updatePool(batch, pid);

    // 2. Transfer pending HONEY to user
    BatchInfo storage targetBatch = batchInfo[batch];
    PoolInfo storage pool = poolInfo[batch][pid];
    uint256 pending = user.amount;
    uint256 power = 100;
    if (user.propEnabled) {
      IHoneyPropDict propDict = IHoneyPropDict(targetBatch.propDict);
      power = propDict.getMiningMultiplier(user.propTokenId);
      pending = pending.mul(power).div(100);
    }
    pending = pending.mul(pool.accHoneyPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0) {
      safeHoneyTransfer(batch, pid, msg.sender, pending);
    }

    // 3. Transfer LP Token from honeycomb to user
    pool.lpToken.safeTransfer(address(msg.sender), amount);
    user.amount = user.amount.sub(amount);

    // 4. Update pool.totalShares & user.rewardDebt
    if (user.propEnabled) {
      pool.totalShares = pool.totalShares.sub(amount.mul(power).div(100));
      user.rewardDebt = user.amount.mul(power).div(100).mul(pool.accHoneyPerShare).div(1e12);
    } else {
      pool.totalShares = pool.totalShares.sub(amount);
      user.rewardDebt = user.amount.mul(pool.accHoneyPerShare).div(1e12);
    }
    
    emit Withdraw(msg.sender, batch, pid, amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 batch, uint256 pid) public {
    require(batch < batchInfo.length, "batch must exist");
    require(pid < poolInfo[batch].length, "pool must exist");

    PoolInfo storage pool = poolInfo[batch][pid];
    UserInfo storage user = userInfo[batch][pid][msg.sender];
    pool.lpToken.safeTransfer(address(msg.sender), user.amount);
    emit EmergencyWithdraw(msg.sender, batch, pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  function depositProp(uint256 batch, uint256 pid, uint256 propTokenId) public {
    require(batch < batchInfo.length, "batch must exist");
    require(pid < poolInfo[batch].length, "pool must exist");

    UserInfo storage user = userInfo[batch][pid][msg.sender];
    require(!user.propEnabled, "another prop is already enabled");

    BatchInfo storage targetBatch = batchInfo[batch];
    IERC721 propToken = IERC721(targetBatch.prop);
    require(propToken.ownerOf(propTokenId) == address(msg.sender), "must be the prop's owner");

    // 1. Update pool.accHoneyPerShare
    updatePool(batch, pid);

    // 2. Transfer pending HONEY to user
    PoolInfo storage pool = poolInfo[batch][pid];
    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accHoneyPerShare).div(1e12);
      pending = pending.sub(user.rewardDebt);
      if (pending > 0) {
        safeHoneyTransfer(batch, pid, msg.sender, pending);
      }
    }

    // 3. Transfer Prop from user to honeycomb
    propToken.safeTransferFrom(address(msg.sender), address(this), propTokenId);
    user.propEnabled = true;
    user.propTokenId = propTokenId;

    // 4. Update pool.totalShares & user.rewardDebt
    IHoneyPropDict propDict = IHoneyPropDict(targetBatch.propDict);
    uint256 power = propDict.getMiningMultiplier(user.propTokenId);
    pool.totalShares = pool.totalShares.sub(user.amount);
    pool.totalShares = pool.totalShares.add(user.amount.mul(power).div(100));
    user.rewardDebt = user.amount.mul(power).div(100).mul(pool.accHoneyPerShare).div(1e12);

    emit DepositProp(msg.sender, batch, pid, propTokenId);
  }

  function withdrawProp(uint256 batch, uint256 pid, uint256 propTokenId) public {
    require(batch < batchInfo.length, "batch must exist");
    require(pid < poolInfo[batch].length, "pool must exist");

    UserInfo storage user = userInfo[batch][pid][msg.sender];
    require(user.propEnabled, "no prop is yet enabled");
    require(propTokenId == user.propTokenId, "must be the owner of the prop");

    BatchInfo storage targetBatch = batchInfo[batch];
    IERC721 propToken = IERC721(targetBatch.prop);
    require(propToken.ownerOf(propTokenId) == address(this), "the prop is not staked");

    // 1. Update pool.accHoneyPerShare
    updatePool(batch, pid);

    // 2. Transfer pending HONEY to user
    PoolInfo storage pool = poolInfo[batch][pid];
    IHoneyPropDict propDict = IHoneyPropDict(targetBatch.propDict);
    uint256 power = propDict.getMiningMultiplier(user.propTokenId);
    uint256 pending = user.amount.mul(power).div(100);
    pending = pending.mul(pool.accHoneyPerShare).div(1e12);
    pending = pending.sub(user.rewardDebt);
    if (pending > 0) {
      safeHoneyTransfer(batch, pid, msg.sender, pending);
    }

    // 3. Transfer Prop from honeycomb to user
    propToken.safeTransferFrom(address(this), address(msg.sender), propTokenId);
    user.propEnabled = false;
    user.propTokenId = 0;
  
    // 4. Update pool.totalShares & user.rewardDebt
    pool.totalShares = pool.totalShares.sub(user.amount.mul(power).div(100));
    pool.totalShares = pool.totalShares.add(user.amount);
    user.rewardDebt = user.amount.mul(pool.accHoneyPerShare).div(1e12);

    emit WithdrawProp(msg.sender, batch, pid, propTokenId);
  }

  function migrate(uint256 toBatch, uint256 toPid, uint256 amount, uint256 fromBatch, uint256 fromPid) public {
    require(toBatch < batchInfo.length, "target batch must exist");
    require(toPid < poolInfo[toBatch].length, "target pool must exist");
    require(fromBatch < batchInfo.length, "source batch must exist");
    require(fromPid < poolInfo[fromBatch].length, "source pool must exist");

    BatchInfo storage targetBatch = batchInfo[toBatch];
    require(block.number < targetBatch.endBlock, "batch ended");

    UserInfo storage userFrom = userInfo[fromBatch][fromPid][msg.sender];
    if (userFrom.amount > 0) {
      PoolInfo storage poolFrom = poolInfo[fromBatch][fromPid];
      PoolInfo storage poolTo = poolInfo[toBatch][toPid];
      require(address(poolFrom.lpToken) == address(poolTo.lpToken), "must be the same token");
      withdraw(fromBatch, fromPid, amount);
      deposit(toBatch, toPid, amount);
    }
  }

  function migrateProp(uint256 toBatch, uint256 toPid, uint256 propTokenId, uint256 fromBatch, uint256 fromPid) public {
    require(toBatch < batchInfo.length, "target batch must exist");
    require(toPid < poolInfo[toBatch].length, "target pool must exist");
    require(fromBatch < batchInfo.length, "source batch must exist");
    require(fromPid < poolInfo[fromBatch].length, "source pool must exist");

    BatchInfo storage sourceBatch = batchInfo[fromBatch];
    BatchInfo storage targetBatch = batchInfo[toBatch];
    require(block.number < targetBatch.endBlock, "batch ended");
    require(targetBatch.prop == sourceBatch.prop, "prop not compatible");
    require(targetBatch.propDict == sourceBatch.propDict, "propDict not compatible");
    UserInfo storage userFrom = userInfo[fromBatch][fromPid][msg.sender];
    require(userFrom.propEnabled, "no prop is yet enabled");
    require(propTokenId == userFrom.propTokenId, "propTokenId not yours");
    UserInfo storage userTo = userInfo[toBatch][toPid][msg.sender];
    require(!userTo.propEnabled, "another prop is already enabled");

    withdrawProp(fromBatch, fromPid, propTokenId);
    depositProp(toBatch, toPid, propTokenId);
  }

  // Safe honey transfer function, just in case if rounding error causes pool to not have enough HONEYs.
  function safeHoneyTransfer(uint256 batch, uint256 pid, address to, uint256 amount) internal {
    uint256 honeyBal = honeyToken.balanceOf(address(this));
    require(honeyBal > 0, "insufficient HONEY balance");

    UserInfo storage user = userInfo[batch][pid][to];
    if (amount > honeyBal) {
      honeyToken.transfer(to, honeyBal);
      user.earned = user.earned.add(honeyBal);
    } else {
      honeyToken.transfer(to, amount);
      user.earned = user.earned.add(amount);
    }
  }

  function onERC721Received(address, address, uint256, bytes calldata) external override returns(bytes4) {
    return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }
}
