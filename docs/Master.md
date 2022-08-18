Master Contract 
======================
The `Master` contract implements the whitelisting of Stable Coins, Calculation of various amounts using Oracle and setting of penalty for Capx Lend.

Constants
-------------

* `uint256 private constant DAY`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Signifies the number of seconds in a day.

Variables
-------------

* `uint96 public penalty`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Signifies the penalty percentage in case of early repayment.

* `address public oracle`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Oracle contract address.

* `address public lend`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Lend contract address.

* `address public controller`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Capx liquid controller.

* `mapping(address => bool) public stableCoins`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Keeps a map of whitelisted stable coins to be used as collateral.


Functions 
-----------------

<br>

### `initialize`

```solidity
function initialize(address _oracle, uint96 _penalty) public 
  initializer
```
While deploying, `deployProxy` internally calls this initializer for the master contract. This function sets `oracle` address and `penalty` percentage.

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

### `setLendContract`

```solidity
  function setLendContract(address _lend) external virtual onlyOwner
```

Functionality  
* Sets new lend contract address.

Inputs required
* `_lend` - Address of the lend contract

<br>

### `setController`

```solidity
  function setController(address _controller) external virtual onlyOwner
```

Functionality  
* Sets a new liquid controller.

Inputs required
* `_controller` - Address of liquid controller.

<br>

### `addStable`

```solidity
   function addStable(address[] memory _stableCoins, bool[] memory _state)
        external
        virtual
        onlyOwner
```

Functionality  
* Whitelists a stable coin to be used as collateral. Can also be used to delist a token in case of unusual circumstances(for instance stable coin depeged).

Inputs required
* `_stableCoins` - Array of stable coin token addresses.
* `_state` - Array of Boolean to update the whitelist state of token addresses.

<br>

### `setPenalty`

```solidity
  function setPenalty(uint96 _newPenalty) external virtual onlyOwner
```

Functionality  
* Used to set new pentaly percentage.

Inputs required
* `_newPenalty` - New penalty percentage.

<br>

### `healthFactor`

```solidity
  function healthFactor(uint256 _loan) public view returns (uint256)
```

Functionality  
* Returns health factor of a specific loan ID.

Inputs required
* `_loan` - Identifier of the loan.

<br>

### `loanRepaymentAmount`

```solidity
  function loanRepaymentAmount(uint256 _loan) public view returns (uint256)
```

Functionality  
* Calculates and returns the amount needed for loan repayment.

Inputs required
* `_loan` - Identifier of the loan.

<br>

### `liquidationAmount`

```solidity
  function liquidationAmount(uint256 _loan)
        public
        view
        returns (uint256, uint256)
```

Functionality  
* Calculates and returns the liquidation amount for a specific loan.

Inputs required
* `_loan` - Identifier of the loan.

<br>

### `wvtAmountCalculation`

```solidity
  function wvtAmountCalculation(
        uint256 _stableCoinAmount,
        address _wvtAddress,
        address _stableCoinAddress,
        uint96 _loanToValue,
        uint96 _discount
    ) public view returns (uint256)
```

Functionality  
* Returns the WVT amount corresponding to the parameters given against the stable coin amount.

Inputs required
* `_stableCoinAmount` - Amount of stable coin.
* `_wvtAddress` - WVT address.
* `_stableCoinAddress` - Stable coin address.
* `_loanToValue` - LTV percentage.
* `_discount` - Discount percentage.

<br>

### `stablecoinAmountCalculation`

```solidity
   function stablecoinAmountCalculation(
        uint256 _wvtAmount,
        address _wvtAddress,
        address _stableCoinAddress,
        uint96 _loanToValue,
        uint96 _discount
    ) public view returns (uint256)
```

Functionality  
* Returns the stable coin amount corresponding to the parameters given against the WVT amount.

Inputs required
* `_wvtAmount` - Amount of WVT.
* `_wvtAddress` - WVT address.
* `_stableCoinAddress` - Stable coin address.
* `_loanToValue` - LTV percentage.
* `_discount` - Discount percentage.

<br>

### `getValidWvt`

```solidity
   function getValidWvt(address _wvt) external view returns (bool)
```

Functionality  
* Returns true or false depending on if the address provided is a valid WVT.

Inputs required
* `_wvt` - WVT address.

<br>

### `pullFailurePeanlty`

```solidity
   function pullFailurePeanlty(uint256 _loanID)
        external
        view
        returns (uint256)
```

Functionality  
* Returns the penalty amount in case tokens are not pulled by borrower within  a day.

Inputs required
* `_loanID` - Identifier of the loan.