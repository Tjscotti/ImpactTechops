#write a powershell function to remove a specific number from an array.
function Remove-Number {
    param(
        [int[]]$array,
        [int]$number
    )
    $array | Where-Object {$_ -ne $number}
}