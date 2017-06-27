#!/bin/bash
# This script reads the values of an item from openhab via REST and imports the data to influxdb
# useage: get_item_states.sh <itemname>


itemname="$1"

if [ -z $itemname ]
then
  echo "Please define Item!"
  exit 0
fi

source ./config.cfg

# convert historical times to unix timestamps,
tenyearsago=`date +"%Y-%m-%dT%H:%M:%S%:z" --date="10 years ago"`
oneyearago=`date +"%Y-%m-%dT%H:%M:%S%:z" --date="-12 months 28 days ago"`
onemonthago=`date +"%Y-%m-%dT%H:%M:%S%:z" --date="29 days ago"`
oneweekago=`date +"%Y-%m-%dT%H:%M:%S%:z" --date="-6 days -23 hours 59 minutes ago"`
onedayago=`date +"%Y-%m-%dT%H:%M:%S%:z" --date="-23 hours 59 minutes ago"`
eighthoursago=`date +"%Y-%m-%dT%H:%M:%S%:z" --date="-7 hours 59 minutes ago"`


# print out timestamps
echo "item:$itemname"
echo "10y: $tenyearsago"
echo "1y:  $oneyearago"
echo "1m:  $onemonthago"
echo "1w:  $oneweekago"
echo "1d:  $onedayago"
echo "8h:  $eighthoursago"


# get values and write to different files
curl -X GET --header "Accept: application/json" "http://$openhabserver:$openhabport/rest/persistence/items/$itemname?starttime=${tenyearsago}&endtime=${oneyearago}"  > ${itemname}_10y.xml
curl -X GET --header "Accept: application/json" "http://$openhabserver:$openhabport/rest/persistence/items/$itemname?starttime=${oneyearago}&endtime=${onemonthago}"  > ${itemname}_1y.xml
curl -X GET --header "Accept: application/json" "http://$openhabserver:$openhabport/rest/persistence/items/$itemname?starttime=${onemonthago}&endtime=${oneweekago}"  > ${itemname}_1m.xml
curl -X GET --header "Accept: application/json" "http://$openhabserver:$openhabport/rest/persistence/items/$itemname?starttime=${oneweekago}&endtime=${onwdayago}"    > ${itemname}_1w.xml
curl -X GET --header "Accept: application/json" "http://$openhabserver:$openhabport/rest/persistence/items/$itemname?starttime=${onedayago}&endtime=${eighthoursago}" > ${itemname}_1d.xml
curl -X GET --header "Accept: application/json" "http://$openhabserver:$openhabport/rest/persistence/items/$itemname?starttime=${eighthoursago}"                      > ${itemname}_8h.xml

# combine files
cat ${itemname}_10y.xml ${itemname}_1y.xml ${itemname}_1m.xml ${itemname}_1w.xml ${itemname}_1d.xml ${itemname}_8h.xml > ${itemname}.xml

# convert data to line protocol file
cat ${itemname}.xml | grep -e "time" -e "state" | paste - - | tr -d ',"' | awk -v item="$itemname" '{print item " value=" $4 " " $2 "000000"}' > ${itemname}.txt

values=`wc -l ${itemname}.txt | cut -d " " -f 1`
echo "found values: $values"



# print import command
echo "curl -i -XPOST -u $influxuser:$influxpw 'http://$influxserver:$influxport/write?db=$influxdatbase' --data-binary @${itemname}.txt"
# execute import command
curl -i -XPOST -u $influxuser:$influxpw "http://$influxserver:$influxport/write?db=$influxdatbase" --data-binary @${itemname}.txt