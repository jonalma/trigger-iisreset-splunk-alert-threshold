#!/bin/bash


############# FUNCTIONS
function app_pool_recycle(){
	RD_TOKEN=$1
  	port=$2
	server=$3
	echo "Starting app pool recycle..."
	curl -s -X POST -H X-Rundeck-Auth-Token:$RD_TOKEN --data-urlencode "argString=-port $port -servers $server" accept:application/json "$rundeck_api_endpoint" | head -n 1

}

function iis_reset(){
	RD_TOKEN=$1
        server=$2
	
	echo "Starting IIS reset..."
        # iis reset
        curl -s -X POST -H X-Rundeck-Auth-Token:$RD_TOKEN --data-urlencode "argString=-servers $server" accept:application/json "$rundeck_api_endpoint" | head -n 1


}
######### END FUNCTIONS


######### MAIN

# get events and place them in JSON array
main_curl='curl -sku "$user:$pw" https://$splunk_server_api_endpoint -d search="$splunk_query" -d output_mode=json '
curl_with_slurp=''"$main_curl"' | jq -s '.''
#output all details in json file
eval $curl_with_slurp > $json_file

# check if Splunk returned any hosts that have high CC - check if host key exists
any_hosts=$(eval $main_curl | jq '.host')

# check if $any_hosts is equal to "null"
if [ "$any_hosts" = "null" ]; then
	echo "$any_hosts - There are no hosts with high CC"
	exit
else
	echo "Found hosts with high CC greater than $cc_threshold"
	output_hosts=''"$main_curl"' | jq '.result.host' | sed "s/\"//g" | sed -z "s/\n/,/g" | sed "s/.$//g"' 
	affected_hosts=$(eval $output_hosts)
	echo $affected_hosts
	echo ""
fi

# check if host already exists in recycle_timestamp-$app.json file
servers=$(eval "$main_curl"' | jq -sc '.'') 
for row in $(echo "${servers}" | jq -r '.[] | @base64'); do
   # function to return individual servers 
   _jq() {
    	echo ${row} | base64 --decode | jq -r ${1}
    }

   server=$(_jq '.result.host')
   echo "$server - checking if host has IIS reset recently..."
   
   # $exists_var returns true or false, if server exists in JSON recycle timestamp file 
   exists_var=$(jq '.[].host|contains("'$server'")' $json_audit_recycle_timestamp| /usr/bin/egrep true)
   
   
   # calculate time difference
   current_timestamp=$(($(date +%s%N)/1000000))
   last_recycle_timestamp=$(jq '.[]|select(.host=="'$server'")|.last_recycle_timestamp' $json_audit_recycle_timestamp | sed "s/\"//g")
   #last_recycle_time_human=$(date -d @$last_recycle_timestamp)
   time_difference_epoch=$((current_timestamp-last_recycle_timestamp))
   time_difference_in_minutes=$(($time_difference_epoch/(60*1000)))
	   
   time_threshold=20 #min
   time_threshold_in_epoch=$((time_threshold*60*1000))

   if [ "$exists_var" = "true" ];
   then
	   echo "$server EXISTS in file."
	   echo "$server - Checking if $server was recently II reset..."
	   
	   # check if ($current_timestamp - $last_recycle_timestamp) is greater than 20 minutes
	   if [ "$time_difference_in_minutes" -ge "$time_threshold" ];
	   then
		 echo "$server - Last app recycle was $time_difference_in_minutes minutes ago... ($time_difference_in_minutes > $time_threshold)"
		 echo "$server - updating iisreset timestamp..."
	         
		 # update last_recycle_timestamp
		 echo "$server - Old timestamp: $last_recycle_timestamp" 
		 echo "$server - New timestamp: $current_timestamp" 
	 	 
		 # Call python script to replace the server's last_recycle_timestamp (args: server, current timestamp, JSON file
                 python replace_last_recycle_timestamp.py $server $current_timestamp $json_audit_recycle_timestamp

		 #issue app pool recycle via Rundeck API here
		 echo "$server - invoking IISRESET on $server ..."
		 
		 # call recycle_servers.ps1
		 #app_pool_recycle $RD_TOKEN $port $server
		 iis_reset $RD_TOKEN $server
		  
	   else
		   echo "$server - IIS has been recently reset ($time_difference_in_minutes min ago)"
		   echo "$server - Must be greater than $time_threshold minutes. Not IIS resetting..."
	   fi
   else
	   # call python script to add new server and timestamp of recycle
	   echo "$server - IIS reset has not been done, adding host in $json_audit_recycle_timestamp"
	   python addobject_last_recycle_timestamp.py $server $current_timestamp $json_audit_recycle_timestamp
	   #issue app pool recycle
	   echo "$server - invoking IISRESET on $server ..."
	   #app_pool_recycle $RD_TOKEN $port $server
	   iis_reset $RD_TOKEN $server
   fi
   
   echo "--" 
done

#jq '.' $json_file
