pragma solidity ^0.4.11;

contract TestOOG {
    /// Allowed transaction types mask
    uint32 constant None = 0;
    uint32 constant All = 0xffffffff;
    uint32 constant Basic = 0x01;
    uint32 constant Call = 0x02;
    uint32 constant Create = 0x04;
    uint32 constant Private = 0x08;

    function allowedTxTypes(address sender) public returns (uint32)
    {
        if (sender == 0xf22210CD5930f0d194Bf38e52d80F3c02d5C4743) return All; // Secret: 0x00..01
        if (sender == 0xD924a3396402f5261E9ff67A5E659e79c6Ebe85A) return Basic | Call; // Secret: 0x00..02
        if (sender == 0x6813eb9362372eef6200f3b1dbc3f819671cba69) return Basic; // Secret: 0x00..03
        if (sender == 0x86895B630B9ad92794FCA5d88B4465DEDf42bBA5) return Basic; // Secret: 0x00..03
        
        return None;
    }
}