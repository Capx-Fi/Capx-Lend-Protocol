Lend Contract 
======================
The `Lend` contract implements the create, cancel, accept, repay and liquidate functionalities of Capx Lend.

Constants
-------------

* `uint256 private constant DAY`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Signifies the number of seconds in a day.

Structs
-------
* `loanDetails1` - Stores details corresponding to the Loan.
 ```solidity
  struct loanDetails1 {
        address wvtAddress;
        uint96 interestRate;
        address stablecoinAddress;
        uint96 loanToValue;
        address lenderAddress;
        uint96 discount;
        address borrowerAddress;
        uint96 liquidationThreshold;
    }
  ```

* `loanDetails2` - Stores details corresponding to the Loan.
 ```solidity
  struct loanDetails2 {
        uint256 endTime;
        uint256 initiationTime;
        uint256 wvtAmount;
        uint256 stablecoinAmount;
        bool externalLiquidation;
        uint8 stageOfLoan;
    }
  ```

Variables
-------------

* `uint256 public loanID`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Signifies the number of Loans by the contract.

* `address public master`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Master contract address.

* `address public lendnft`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; LendNFT contract address.

* `mapping(uint256 => loanDetails1) public loanBook1`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Stores the loandetails1 corresponding to the loanID.

* `mapping(uint256 => loanDetails2) public loanBook2`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Stores the loandetails2 corresponding to the loanID.


Events
-------------

### `CreateLoan` Event

```solidity
event CreateLoan(
    uint256 loanID,
    address collateralAddress,
    address stableCoin,
    bool borrower,
    uint256 amount,
    uint96 interestrate,
    uint96 ltv,
    uint96 lt,
    uint256 duration,
    uint96 discount,
    bool externalLiquidate
);
```
> Event emitted when an loan is created.
* `loanID` - LoanID for the created loan.
* `collateralAddress` - WVT address that is put up as Collateral.
* `stableCoin` - Stable coin address.
* `borrower` - Signifies if the loan is created by Borrower.
* `amount` - Amount of loan.
* `interestrate` - Interest Rate of loan.
* `ltv` - Loan-to-Value ratio of loan.
* `lt` - Liquidation Threshold of loan.
* `duration` - Duration of loan.
* `discount` - Discount % provided w.r.t WVTs current price.
* `externalLiquidate` - Signifies if anyone can liquidate the loan.

<br>

### `AcceptLoan` Event

```solidity
event AcceptLoan(
    uint256 loanID,
    bool externalLiquidation,
    uint256 wvtAmount,
    uint256 stableCoinAmount,
    uint256 initiationTime
);
```
> Event emitted when an loan is accepted.
* `loanID` - LoanID for the created loan.
* `wvtAmount` - Amount of WVT for the loan.
* `stableCoinAmount` - Amount of Stable coin for the loan.
* `initiationTime` - Timestamp at which the loan initiates.
* `externalLiquidation` - Signifies if anyone can liquidate the loan.

<br>

### `CancelLoan` Event

```solidity
event CancelLoan(
    uint256 loanID
);
```
> Event emitted when an loan is cancelled.
* `loanID` - LoanID for the loan.

<br>

### `PullAsset` Event

```solidity
event PullAsset(
    uint256 loanID, 
    uint256 initiationTime
);
```
> Event emitted when an loan is pulled.
* `loanID` - LoanID for the loan.
* `initiationTime` - Initiation Time of the loan.

<br>

### `LiquidateLoan` Event

```solidity
event LiquidateLoan(
    uint256 loanID,
    uint256 stableContractAmount,
    uint256 stablePushAmount
);
```
> Event emitted when an loan is pulled.
* `loanID` - LoanID for the loan.
* `stableContractAmount` - Stable Coin amount to be kept by the Lend contract.
* `stablePushAmount` - Stable Coin amount to be sent to the lender.

<br>

### `RepayLoan` Event

```solidity
event RepayLoan(
    uint256 loanID
);
```
> Event emitted when an loan is repayed.
* `loanID` - LoanID for the loan.

Functions 
-----------------

<br>

### `initialize`

```solidity
function initialize() public 
  initializer
```
While deploying, `deployProxy` internally calls this initializer for the exchange contract. This function sets `master`, `lendnft` address and sets the `loanID` to 0.

<br>

### `_authorizeUpgrade`

```solidity
  function _authorizeUpgrade(
    address _newImplementation
    ) internal 
    override 
    onlyOwner
```
Function responsible to internally update the smart contract, ideally it should revert when msg.sender is not authorized to upgrade the contract.

<br>

### `createLoan`

```solidity
  function createLoan (
        address _collateralAddress,
        address _stablecoinAddress,
        bool _borrower,
        uint256 _amount,
        uint96 _interestRate,
        uint96 _loanToValue,
        uint96 _liquidationThreshold,
        uint256 _duration,
        uint96 _discount,
        bool _externalLiquidate
    ) external virtual nonReentrant whenNotPaused
```

Functionality  
* Creation of new Loan.

Inputs required
* `_collateralAddress` - Address of the collateral token
* `_stablecoinAddress` - Address of the lending token
* `_borrower` - boolean if the msg.sender is borrower or lender
* `_amount` - amount of token user want to lend or borrow
* `_interestRate` - interest rate charged
* `_loanToValue` - loan to value percentage
* `_liquidationThreshold` - liquidation percentage
* `_duration` - duration of the loan
* `_externalLiquidate` - If lender is calling he can specify if external party can liquidate or not

<br>

### `cancelLoan`

```solidity
  function cancelLoan(
      uint256 _loanID
    ) external
    virtual
    nonReentrant
    whenNotPaused
```

Functionality  
* Cancel a loan, if not already accepted.

Inputs required
* `_loanID` - Identifier of the loan.

<br>

### `acceptLoan`

```solidity
  function acceptLoan(
      uint256 _loanID, 
      bool _externalLiquidation
    ) external
    virtual
    nonReentrant
    whenNotPaused
```

Functionality  
* Accepts a loan, if not already accepted.

Inputs required
* `_loanID` - Identifier of the loan.
* `_externalLiquidation` - boolean flag to determine if anyone can liquidate the loan.

<br>

### `pullAssets`

```solidity
  function pullAssets(
      uint256 _loanID
    ) external
    virtual
    nonReentrant
    whenNotPaused
```

Functionality  
* Provides the borrower with the functionality to pull his assets after acceptance by lender, which eventually cancels out the loan.

Inputs required
* `_loanID` - Identifier of the loan.

<br>

### `repaymentLoan`

```solidity
  function repaymentLoan(
      uint256 _loanID
    ) external
    virtual
    nonReentrant
    whenNotPaused
```

Functionality  
* Provides the borrower with the functionality to repay the loan.

Inputs required
* `_loanID` - Identifier of the loan.

<br>

### `liquidation`

```solidity
  function liquidation(
      uint256 _loanID
    ) external
    virtual
    nonReentrant
    whenNotPaused
```

Functionality  
* Provides the user with the functionality to liquidate defaulted loan.

Inputs required
* `_loanID` - Identifier of the loan.
