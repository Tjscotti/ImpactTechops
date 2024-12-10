switch (1,4,-1,3,"Hello",2,1)
{
    {$_ -lt 0} { continue }
    {$_ -isnot [Int32]} { break }
    {$_ % 2} {
        "$_ is Odd"
    }
    {-not ($_ % 2)} {
        "$_ is Even"
    }
}


For ($i = 0; $i –lt 3; $i++) {
    Write $i
   }

   0..3 | ForEach-Object { Write $_ }