#!/bin/bash
# Run dx_Magic scripts every 2 seconds

echo "dx_Magic scripts now looping" | logger -t dx_Magic

while true
do 
perl /root/dxMagic/perl/dx_extract.pl | logger -t dx_Magic 
perl /root/dxMagic/perl/dx_xlsx2txt.pl | logger -t dx_Magic
sleep 1
perl /root/dxMagic/perl/dx_insert.pl | logger -t dx_Magic
sleep 1
done

