function Get-HexEncodedString([String]$unencodedString) {
    $charArray = $unencodedString.ToCharArray();    
    Foreach ($eachChar in $charArray) {$returnString = $returnString + [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($eachChar))}
    return "0x" + $returnString
}

function Get-RandomStringPhrase([int]$stringLength) {
    return -join ((48..57) + (97..122) | Get-Random -Count $stringLength | % {[char]$_})
}

Export-ModuleMember -Function Get-HexEncodedString
Export-ModuleMember -Function Get-RandomStringPhrase
