#!/bin/bash
# dx_looper V 0.0.2
# Run dx_Magic scripts every 2 seconds

echo "dx_Magic scripts now looping" | logger -t dx_Magic

while true
do 
perl /root/dxMagic/perl/dx_extract.pl | logger -t dx_Magic 
perl /root/dxMagic/perl/dx_xlsx2txt.pl | logger -t dx_Magic
# -i option uses insert WATCH for source and destination
perl /root/dxMagic/perl/dx_xlsx2txt.pl -i | logger -t dx_Magic
sleep 1
perl /root/dxMagic/perl/dx_insert.pl | logger -t dx_Magic
sleep 1
done

