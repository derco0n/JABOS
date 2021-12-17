#!/bin/bash

### Script installs root.cert.pem to certificate trust store of applications using NSS
### (e.g. Firefox, Thunderbird, Chromium)
### Mozilla uses cert8, Chromium and Chrome use cert9

###
### Requirement: apt install libnss3-tools
###


###
### CA file to install (CUSTOMIZE!)
###
function printhelp {
    echo ""
    echo "$0 - imports CA_certificates into firefox"    
    echo "Usage: $0 <certfile> <certname>"
    echo ""
    echo "certfile - file that contains a CA-certificate"
    echo "certname - name for the certificate to import"
}

if [ -z "$1" ]; then 
    echo "certfile not given";
    printhelp;
    exit 1;
fi

if [ -z "$2" ]; then 
    echo "certname not given";
    printhelp;
    exit 2;
fi

###
### Check if certutil is installed
###
installed=$(apt list --installed 2> /dev/null | grep libnss3-tools)

if [[ -z $installed ]]; then
    echo "certutil is not installed. Install it first using command: >>sudo apt install libnss3-tools -y<<"
    exit 3
else
     echo "libnss3-tools is installed. Assuming certutil is available"
fi


certfile=$1
certname=$2


###
### For cert8 (legacy - DBM)
###

for certDB in $(find ~/ -name "cert8.db")
do
    certdir=$(dirname ${certDB});
    certutil -A -n "${certname}" -t "TCu,Cu,Tu" -i ${certfile} -d dbm:${certdir}
done


###
### For cert9 (SQL)
###

for certDB in $(find ~/ -name "cert9.db")
do
    certdir=$(dirname ${certDB});
    certutil -A -n "${certname}" -t "TCu,Cu,Tu" -i ${certfile} -d sql:${certdir}
done
