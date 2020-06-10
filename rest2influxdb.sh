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
tenyearsago=`date +"%Y-%m-%dT%H:%M:%S%" --date="10 years ago"`
oneyearago=`date +"%Y-%m-%dT%H:%M:%S%" --date="-12 months 28 days ago"`
onemonthago=`date +"%Y-%m-%dT%H:%M:%S%" --date="29 days ago"`
oneweekago=`date +"%Y-%m-%dT%H:%M:%S%" --date="-6 days -23 hours 59 minutes ago"`
onedayago=`date +"%Y-%m-%dT%H:%M:%S%" --date="-23 hours 59 minutes ago"`
eighthoursago=`date +"%Y-%m-%dT%H:%M:%S%" --date="-7 hours 59 minutes ago"`


# print timestamps
echo ""
echo "### timestamps"
echo "item: $itemname"
echo "10y:  $tenyearsago"
echo "1y:   $oneyearago"
echo "1m:   $onemonthago"
echo "1w:   $oneweekago"
echo "1d:   $onedayago"
echo "8h:   $eighthoursago"

resturl="http://$openhabserver:$openhabport/rest/persistence/items/$itemname?serviceId=$serviceid&api_key=$itemname"

echo "resturl:   $resturl"

# get values and write to different files
# curl -X GET --header "Accept: application/json" "$resturl&starttime=${tenyearsago}&endtime=${oneyearago}"  > ${itemname}_10y.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${tenyearsago}&endtime=${oneyearago}"  > ${itemname}_10y.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${oneyearago}&endtime=${onemonthago}"  > ${itemname}_1y.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${onemonthago}&endtime=${oneweekago}"  > ${itemname}_1m.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${oneweekago}&endtime=${onedayago}"    > ${itemname}_1w.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${onedayago}&endtime=${eighthoursago}" > ${itemname}_1d.xml
curl -X GET --header "Accept: application/json" "$resturl&starttime=${eighthoursago}"                      > ${itemname}_8h.xml

# combine files
cat ${itemname}_10y.xml ${itemname}_1y.xml ${itemname}_1m.xml ${itemname}_1w.xml ${itemname}_1d.xml ${itemname}_8h.xml > ${itemname}.xml

# convert data to line protocol file
cat ${itemname}.xml \
     | sed 's/}/\n/g' \
     | sed 's/data/\n/g' \
     | grep -e "time.*state"\
     | tr -d ',:[{"' \
     | sed 's/time/ /g;s/state/ /g' \
     | awk -v item="$itemname" '{print item " value=" $2 " " $1 "000000"}' \
     | sed 's/value=ON/value=1/g;s/value=OFF/value=0/g' \
> ${itemname}.txt

values=`wc -l ${itemname}.txt | cut -d " " -f 1`
echo ""
echo "### found values: $values"


# split file in smaller parts to make it easier for influxdb
split -l $importsize ${itemname}.txt "${itemname}-"

for i in ${itemname}-*
do
  curl -i -XPOST -u $influxuser:$influxpw "http://$influxserver:$influxport/write?db=$influxdatbase" --data-binary @$i
  echo "Sleep for $sleeptime seconds to let InfluxDB process the data..."
  sleep $sleeptime
done

echo ""
echo "### delete temporary files"
rm ${itemname}*

exit 0
