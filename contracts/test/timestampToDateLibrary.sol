// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/// @title TimestampToDateLibrary library for vesting
/// @author Capx Team
/// @notice The TimestampToDateLibrary is the library used to convert timestamp to date,month,year
/// @dev This contract uses mathematical algorithm to calculate the date from timestamp
library TimestampToDateLibrary {
    uint256 internal constant SECONDS_PER_DAY = 24 * 60 * 60;
    int256 internal constant OFFSET19700101 = 2440588;

    /// @notice Function of TimestampToDateLibrary used to convert timestamp to year,month,day
    /// @dev Uses mathematical algorithm to calculate this
    /// @param timestamp Timestamp which is needed to be converted to date
    /// Returns three variables with year,month,day values

    function timestampToDate(uint256 timestamp)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day
        )
    {
        int256 L = int256((timestamp / SECONDS_PER_DAY)) +
            68569 +
            OFFSET19700101;
        int256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        int256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint256(_year);
        month = uint256(_month);
        day = uint256(_day);
    }
}
