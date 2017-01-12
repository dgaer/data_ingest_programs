#!/bin/bash
# -----------------------------------------------------------
# UNIX Shell Script
# Tested Operating System(s): RHEL 6,7
# Tested Run Level(s): 3, 5
# Shell Used: BASH shell
# Original Author(s): Douglas.Gaer@noaa.gov
# File Creation Date: 07/20/2015
# Date Last Modified: 01/12/2017
#
# Version control: 1.04
#
# Support Team:
#
# Contributors: 
#               
# -----------------------------------------------------------
# ------------- Program Description and Details -------------
# -----------------------------------------------------------
#
# Script used to download PSURGE data from NCEP
#
# -----------------------------------------------------------

source ${HOME}/.bashrc

# NOTE: Data is processed on the server in UTC
export TZ=UTC

# Set our data processing directory
DATAdir="/tmp/psurge"
PRODUCTdir="${DATAdir}/ncep_hourly"
SPOOLdir="${DATAdir}/ncep_hourly.spool"

myPWD=$(pwd)

RSYNC="/usr/bin/rsync"
WGETargs="-N -nv --tries=1 --no-remove-listing"
WGET="/usr/bin/wget"

# Meta file
# http://weather.noaa.gov/pub/SL.us008001/ST.opnl/DF.gr2/DC.ndgd/GT.slosh/AR.conus/ds.psurge.txt
# Data directory
# http://nomads.ncep.noaa.gov/pub/data/nccf/com/nhc/prod/psurge.20150616/
# http://nomads.ncep.noaa.gov/pub/data/nccf/com/nhc/prod/psurge.20150616/psurge.t2015061606z.al022015_e10_inc_dat.conus_625m.grib2

echo "Starting PSurge data processing"

# Make any of the following directories if needed
mkdir -p ${PRODUCTdir}
mkdir -p ${SPOOLdir}

# Starting purging here
PSURGEPURGEdays="1"
echo "Purging any PSURGE data older than ${PSURGEPURGEdays} days old"
find ${PRODUCTdir} -type f -mtime +${PSURGEPURGEdays} | xargs rm -f
find ${SPOOLdir} -type f -mtime +${PSURGEPURGEdays} | xargs rm -f

datetime=`date -u`
echo "Starting download at at $datetime UTC"

cd ${SPOOLdir}
url="http://tgftp.nws.noaa.gov/SL.us008001/ST.opnl/DF.gr2/DC.ndgd/GT.slosh/AR.conus"
file="ds.psurge.txt"
echo "Downloading $url/$file"
echo "$WGET ${WGETargs} ${url}/${file}" 2>&1
$WGET ${WGETargs} ${url}/${file} 2>&1

STRMID=$(grep "STRMID" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
STRMID=$(echo "${STRMID}" | sed s/' '//g)
strmid=$(echo "${STRMID}" | tr [:upper:] [:lower:])
NAME=$(grep "NAME" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
NAME=$(echo "${NAME}" | sed s/' '//g)
FILE=$(grep "FILE" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
FILE=$(echo "${FILE}" | sed s/' '//g)
SYNOPTICTIME=$(grep "SYNOPTICTIME" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
SYNOPTICTIME=$(echo "${SYNOPTICTIME}" | sed s/' '//g)
ADVNUM=$(grep "ADVNUM" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
ADVNUM=$(echo "${ADVNUM}" | sed s/' '//g)
ADVTIME=$(grep "ADVTIME" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
ADVTIME=$(echo "${ADVTIME}" | sed s/' '//g)
TIMEZONE=$(grep "TIMEZONE" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
TIMEZONE=$(echo "${TIMEZONE}" | sed s/' '//g)
DEVELTYPE=$(grep "DEVELTYPE" ${SPOOLdir}/${file} | awk -F, '{ print $2 }')
DEVELTYPE=$(echo "${DEVELTYPE}" | sed s/' '//g)

echo "STRMID = ${STRMID}"
echo "NAME = ${NAME}"
echo "FILE = ${FILE}"
echo "SYNOPTICTIME = ${SYNOPTICTIME}"
echo "ADVNUM = ${ADVNUM}"
echo "ADVTIME = ${ADVTIME}"
echo "TIMEZONE = ${TIMEZONE}"
echo "DEVELTYPE = ${DEVELTYPE}"

YYYYMMDD=$(echo "${SYNOPTICTIME}" | cut -b1-8)

current_time=$(date -u +%s)
YYYY=`echo ${SYNOPTICTIME} | cut -b1-4`
MM=`echo ${SYNOPTICTIME} | cut -b5-6`
DD=`echo ${SYNOPTICTIME} | cut -b7-8`
HH=`echo ${SYNOPTICTIME} | cut -b9-10`
time_str="${YYYY} ${MM} ${DD} ${HH} 00 00"
model_start_time=`echo ${time_str} | awk -F: '{ print mktime($1 $2 $3 $4 $5 $6) }'`

diff=$((current_time - model_start_time))
HRS=`expr $diff / 3600`
DAYS=`expr $HRS / 24`
MIN=`expr $diff % 3600 / 60`
SEC=`expr $diff % 3600 % 60`

if [ $DAYS -gt 0 ]
then
    echo "INFO - PSurge files are $DAYS day(s) old, skipping this download"
    exit 0
fi

if [ ! -e ${SPOOLdir}/psurge_prev_downloads.txt ]; then cat /dev/null > ${SPOOLdir}/psurge_prev_downloads.txt; fi

elevels="10 20 30 40 50"
numdownloads=0
for e in ${elevels}
do
    file="psurge.t${SYNOPTICTIME}z.${strmid}_e${e}_inc_dat.conus_625m.grib2"
    while read line
    do
	if [ "${line}" == "${file}" ]
	then
	    echo "INFO: File previously downloaded: ${file}"
	    let numdownloads=numdownloads+1
	fi
    done < ${SPOOLdir}/psurge_prev_downloads.txt
done

if [ $numdownloads -eq 5 ]
then
    echo "INFO - All PSurge files in LDM queue, skipping this download" 
    exit 0
fi

cat /dev/null > ${SPOOLdir}/psurge_prev_downloads.txt

for e in ${elevels}
do
    cd ${SPOOLdir}
    url="http://nomads.ncep.noaa.gov/pub/data/nccf/com/nhc/prod/psurge.${YYYYMMDD}"
    file="psurge.t${SYNOPTICTIME}z.${strmid}_e${e}_inc_dat.conus_625m.grib2"
    outfile="${file}"
    echo "Downloading $url/$file to $outfile"
    echo "$WGET ${WGETargs} ${url}/${file}" 2>&1
    $WGET ${WGETargs} ${url}/${file} 2>&1
    echo "$RSYNC -av ${file} ${PRODUCTdir}/${outfile}" 2>&1
    $RSYNC -av --force ${file} ${PRODUCTdir}/${outfile} 2>&1
    cd ${PRODUCTdir}
    # TODO: Add any clipping here

    echo "${file}" >> ${SPOOLdir}/psurge_prev_downloads.txt
done

datetime=$(date -u)
echo "Ending download at $datetime UTC"
echo "Exiting..."

exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
