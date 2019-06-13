#!/bin/bash
#line divider
ld="=========================================================================================="
linuxOutput=/tmp/object_queries.txt
macOSoutput=/Users/Shared/object_queries.txt
#############################################################
#
#		Title: object_queries.bash
#		Purpose: Identify objects in the database that could cause performance issues
#		Last Update - 5 / 7 / 2019
#
##############################################################
queries[0]="" #mysql query
pic[0]="" #PI Comment
count=0


# MySQL Queries - Update As Needed
# These 3 lines need to be added/removed for each query

# pic[$count]=""
# queries[$count]=""
# ((count++))

pic[$count]="Scripts that have 'jamf recon' or update inventory in it"
queries[$count]="select script_id, file_name from scripts where script_contents like '%jamf recon%';"
((count++))

pic[$count]="Ext Attrib’s that have 'jamf recon' in it (results in an endless recon loop)"
queries[$count]="select extension_attribute_id, display_name from extension_attributes where script_contents_mac like '%jamf recon%';"
((count++))

pic[$count]="Policies that update inventory are enabled, ongoing at recurring checkin, and not available in Self-Service"
queries[$count]="SELECT policy_id, name, trigger_event_checkin, execution_frequency from policies WHERE enabled = 1 AND trigger_event_checkin = 1 AND execution_frequency = 'Ongoing' AND use_for_self_service = 0 AND update_inventory = 1;"
((count++))

pic[$count]="Number of times a policy ran in the last week and updated inventory (varies by enrollment count, but high numbers are generally a sign of looping)"
queries[$count]="SELECT policy_id,count(*) FROM policy_history WHERE completed_epoch>unix_timestamp(date_sub(now(), interval 1 week))*1000 and policy_id IN (SELECT policy_id FROM policies WHERE update_inventory = 1) GROUP BY policy_id ORDER BY Count(*) asc;"
((count++))

pic[$count]="Policies that have ran in the last 12 hours (varies by enrollment count, but high numbers are generally a sign of looping)"
queries[$count]="select b.name, a.policy_id, count(*), b.execution_frequency from policy_history as a, policies as b where a.completed_epoch>unix_timestamp(date_sub(now(), interval 12 hour))*1000 and a.policy_id=b.policy_id group by a.policy_id having count(*)>100 order by count(*);"
((count++))

pic[$count]="Policies that update inventory daily"
queries[$count]="select policy_id, name from policies where trigger_event_checkin = 1 AND execution_frequency = 'Once every day' AND enabled = 1 AND update_inventory = 1 AND use_for_self_service = 0;"
((count++))

pic[$count]="Policies that are enabled, ongoing and recurring checkin not available in Self Service and update inventory"
queries[$count]="SELECT policy_id, name, trigger_event_checkin, execution_frequency from policies WHERE enabled = 1 AND trigger_event_checkin = 1 AND execution_frequency = 'Ongoing' AND use_for_self_service = 0 AND update_inventory = 1;"
((count++))

pic[$count]="Computer groups that are not scoped to anything (smart groups are calculated constantly - a high number not associated with anything could eat up server resources)"
queries[$count]="select computer_group_id, computer_group_name from computer_groups where computer_group_id not in (select target_id from policy_deployment where target_type=7 union select target_id from os_x_configuration_profile_deployment where target_type=7 union select target_id from restricted_software_deployment where target_type=7 union select target_id from managed_preference_profile_deployment where target_type=7 union select target_id from mac_app_deployment where target_type=7 union select target_id from ibook_deployment where target_type=7) and is_smart_group=1;"
((count++))

pic[$count]="Mobile device groups that are not scoped to anything (smart groups are calculated constantly - a high number not associated with anything could eat up server resources)"
queries[$count]="select mobile_device_group_id, mobile_device_group_name from mobile_device_groups where mobile_device_group_id not in (select target_id from ibook_deployment where target_type=25 union select target_id from mobile_device_app_deployment where target_type=25 union select target_id from mobile_device_configuration_profile_deployment where target_type=25) and is_smart_group=1;"
((count++))

pic[$count]="User groups that are not scoped to anything (smart groups are calculated constantly - a high number not associated with anything could eat up server resources)"
queries[$count]="select user_group_id, user_group_name from user_object_groups where user_group_id not in (select target_id from ibook_deployment where target_type=54 union select target_id from mobile_device_app_deployment where target_type=54 union select target_id from mobile_device_configuration_profile_deployment where target_type=54) and is_smart_group=1;"
((count++))

##############################################################
#
# DO NOT EDIT BELOW THIS LINE
#
##############################################################


#set variables for mySQL
#os
read -p "Please identify server operating system. 1 for Linux, 2 for macOS: " OS

#user
read -p "Please enter your MySQL username: " user

#user password hidden from terminal
prompt="Please enter your MySQL password: "
while IFS= read -p "$prompt" -r -s -n 1 char 
do
if [[ $char == $'\0' ]];     then
    break
fi
if [[ $char == $'\177' ]];  then
    prompt=$'\b \b'
    password="${password%?}"
else
    prompt='*'
    password+="$char"
fi
done
#export mysql password to clear warning
export MYSQL_PWD="$password"
echo ""

#database name
read -p "Please enter your Jamf database name: " db

#set mysql and output variables dependant on OS
if [ $OS == "1" ]
then
	#output file
	output=$linuxOutput
	#remove output if found
	if [ -f $output ]
	then
		rm $output
	fi
	#mysql location
	read -p "Please enter the location of the MySql binary (leave blank for default path - /usr/bin/mysql): " mySQL
	if [ -z "$mySQL" ]
	then
		mySQL="/usr/bin/mysql"
	fi
elif [ $OS == "2" ]	
then
	#output file
	output=$macOSoutput
	#remove output if found
	if [ -f $output ]
	then
		rm $output
	fi
	#mysql location
	read -p "Please enter the location of the MySql binary (leave blank for default path - /usr/local/mysql/bin/mysql): " mySQL
	if [ -z "$mySQL" ]
	then 
		mySQL="/usr/local/mysql/bin/mysql"
	fi
fi

#check for MySQL location, gracefully quit if not found in location
if [ -e $mySQL ]
then
	echo "MySQL found, running commands..."
else
	echo "MySQL not found, exiting."
	exit 0
fi

##############################################################

#main function to loop through queries array
function MySQLoutput()
{
	#output the Jamf Pro server version 
	mysqlcommand="select version from db_schema_information;"
	result=$($mySQL -u$user $db -N -e "$mysqlcommand")
	#output server version
	echo $ld >> $output
	echo "Jamf Pro Version: $result" >> $output
	echo $ld >> $output
	echo "" >> $output

	#get the length of the array and a variable for traversing
	totalentries="${#queries[@]}"
	n=0
	#traverse the array and output the mysql commands to a txt file
	while [ $n -lt $totalentries ]
	do
		#output the pi# to the txt file
		i=$((n + 1))
		pi="${pic[$n]}"
		echo $ld >> $output
		echo "$i.) " $pi >> $output
		echo $ld >> $output
		echo "" >> $output
		
		#store mysql command as variable
		mysqlcommand="${queries[$n]}"

		#output query to output file
		echo $mysqlcommand >> $output
		echo "" >> $output

		#output the result of the query to the txt file, output empty set if nothing is found
		result=$($mySQL -u$user $db -t -e "$mysqlcommand")
		if [ -z "$result" ]
		then
			echo "---Empty Set---" >> $output
		else
			echo "$result" >> $output
		fi
		
		echo "" >> $output
		echo "" >> $output
		((n++))
	done
}



##############################################################
#call main function and delcare and exit
MySQLoutput
echo ""
echo "All outputs have been written to $output"
exit 0
