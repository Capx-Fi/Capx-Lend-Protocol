Oracle Contract 
======================
The `Oracle` contract implements the maintaining of price feed addresses.


Variables
-------------

* `address public controller`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Capx liquid controller.

* `mapping(address => address) public assetToFeed;`:<br />
  &ensp;&nbsp;&nbsp;&nbsp;&nbsp; Keeps a map of asset feed against project tokens.


Functions 
-----------------

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

### `updateAssetFeed`

```solidity
   function updateAssetFeed(address _asset, address _feed) public onlyOwner
```

Functionality  
* Updates oracle address against the project token.

Inputs required
* `_asset` - Address of project token.
* `_feed` - Address of oracle feed.

<br>

### `getPrice`

```solidity
  function getPrice(address _wvt) external view returns (uint256, uint256)
```

Functionality  
* Used to get oracle price and decimal of wvt.

Inputs required
* `_wvt` - WVT Address.