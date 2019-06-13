@echo off
set /a count = 0
:: Linebreak
set lb==========================================================================================
:: Output file
set outputfile=C:\object_queries.txt
:: #############################################################
::
::		Title: object_queries.bash
::		Purpose: Identify objects in the database that could cause performance issues
::		Last Update - 5 / 7 / 2019
::
:: ##############################################################


:: MySQL queries update as needed
:: These 3 lines need to be added/removed for each query

:: set "pic[%count%]="
:: set "query[%count%]="
:: set /a count+=1

set "pic[%count%]=Scripts that have 'jamf recon' or update inventory in it"
set "query[%count%]=select script_id, file_name from scripts where script_contents like '%jamf recon%';"
set /a count+=1

set "pic[%count%]=Ext Attrib’s that have 'jamf recon' in it (results in an endless recon loop)"
set "query[%count%]=select extension_attribute_id, display_name from extension_attributes where script_contents_mac like '%jamf recon%';"
set /a count+=1

set "pic[%count%]=Policies that update inventory are enabled, ongoing at recurring checkin, and not available in Self-Service"
set "query[%count%]=SELECT policy_id, name, trigger_event_checkin, execution_frequency from policies WHERE enabled = 1 AND trigger_event_checkin = 1 AND execution_frequency = 'Ongoing' AND use_for_self_service = 0 AND update_inventory = 1;"
set /a count+=1

set "pic[%count%]=Number of times a policy ran in the last week and updated inventory (varies by enrollment count, but high numbers are generally a sign of looping)"
set "query[%count%]=SELECT policy_id,count(*) FROM policy_history WHERE completed_epoch>unix_timestamp(date_sub(now(), interval 1 week))*1000 and policy_id IN (SELECT policy_id FROM policies WHERE update_inventory = 1) GROUP BY policy_id ORDER BY Count(*) asc;"
set /a count+=1

set "pic[%count%]=Policies that have ran in the last 12 hours (varies by enrollment count, but high numbers are generally a sign of looping)"
set "query[%count%]=select b.name, a.policy_id, count(*), b.execution_frequency from policy_history as a, policies as b where a.completed_epoch>unix_timestamp(date_sub(now(), interval 12 hour))*1000 and a.policy_id=b.policy_id group by a.policy_id having count(*)>100 order by count(*);"
set /a count+=1

set "pic[%count%]=Policies that update inventory daily"
set "query[%count%]=select policy_id, name from policies where trigger_event_checkin = 1 AND execution_frequency = 'Once every day' AND enabled = 1 AND update_inventory = 1 AND use_for_self_service = 0;"
set /a count+=1

set "pic[%count%]=Policies that are enabled, ongoing and recurring checkin not available in Self Service and update inventory"
set "query[%count%]=SELECT policy_id, name, trigger_event_checkin, execution_frequency from policies WHERE enabled = 1 AND trigger_event_checkin = 1 AND execution_frequency = 'Ongoing' AND use_for_self_service = 0 AND update_inventory = 1;"
set /a count+=1

set "pic[%count%]=Computer groups that are not scoped to anything (smart groups are calculated constantly - a high number not associated with anything could eat up server resources)"
set "query[%count%]=select computer_group_id, computer_group_name from computer_groups where computer_group_id not in (select target_id from policy_deployment where target_type=7 union select target_id from os_x_configuration_profile_deployment where target_type=7 union select target_id from restricted_software_deployment where target_type=7 union select target_id from managed_preference_profile_deployment where target_type=7 union select target_id from mac_app_deployment where target_type=7 union select target_id from ibook_deployment where target_type=7) and is_smart_group=1;"
set /a count+=1

set "pic[%count%]=Mobile device groups that are not scoped to anything (smart groups are calculated constantly - a high number not associated with anything could eat up server resources)"
set "query[%count%]=select mobile_device_group_id, mobile_device_group_name from mobile_device_groups where mobile_device_group_id not in (select target_id from ibook_deployment where target_type=25 union select target_id from mobile_device_app_deployment where target_type=25 union select target_id from mobile_device_configuration_profile_deployment where target_type=25) and is_smart_group=1;"
set /a count+=1

set "pic[%count%]=User groups that are not scoped to anything (smart groups are calculated constantly - a high number not associated with anything could eat up server resources)"
set "query[%count%]=select user_group_id, user_group_name from user_object_groups where user_group_id not in (select target_id from ibook_deployment where target_type=54 union select target_id from mobile_device_app_deployment where target_type=54 union select target_id from mobile_device_configuration_profile_deployment where target_type=54) and is_smart_group=1;"
set /a count+=1


:: ###############DO NOT EDIT BELOW THIS LINE####################


:: Username
set /p user="Please enter your MySQL username: "
:: User Password
set "psCommand=powershell -Command "$password = read-host 'Please enter your MySQL password' -AsSecureString ; ^
      $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password); ^
            [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)""
 for /f "usebackq delims=" %%p in (`%psCommand%`) do set password=%%p
:: Database Name
set /p db="Please enter your Jamf database name: "
:: MySQL Version
set /p ver="Please enter your MySQL version (Ex - 5.7 or 8.0): "
:: Check for MySQL
if exist "C:\Program Files\MySQL\MySQL Server %ver%\bin\mysql.exe" (
    echo "MySQL found, running commands..."
) else (
    echo "MySQL not found, exiting."
    PAUSE
    exit
)

:: remove output file if found
if exist "%outputfile%" (
	del "%outputfile%"
) else (
	echo. >> %outputfile%
)


:: Get Jamf Pro Version
echo %lb% >> %outputfile%
echo Jamf Pro Version: >> %outputfile%
"C:\Program Files\MySQL\MySQL Server %ver%\bin\mysql.exe" -u %user% -p%password% %db% -N -e "select version from db_schema_information;" >> %outputfile%
echo %lb% >> %outputfile%


:: Store MySQL command as variable
set MySQL="C:\Program Files\MySQL\MySQL Server %ver%\bin\mysql.exe" -u %user% -p%password% %db% -t -e

:: ##############################################################

::loop through query index and provide outputs
set /a index = 0
:while
	set tmp="C:\tmp.txt"	
	setlocal enableDelayedExpansion
	echo. >> %outputfile%
	echo. >> %outputfile%

	::output the PI comment/note
	echo %lb% >> %outputfile%
	set /a n = index+1
	echo %n%.) !pic[%index%]! >> %outputfile%
	echo %lb% >> %outputfile%
	
	echo. >> %outputfile%
	
	::output the mysql query
	echo !query[%index%]! >> %outputfile%
	
	echo. >> %outputfile%


	::run mysql query and store output into a tmp file
	set result=%MySQL% "!query[%index%]!"
	%result% >> %tmp%
	set /p tmpresult=< %tmp%

	
	::output result to output file, format an empty set return if variable is empty
	if [%tmpresult%]==[] (
		echo ---Empty Set--- >> %outputfile%
	) else (
		%result% >> %outputfile%
	)

	endlocal
	del %tmp%
	set /a index+=1
if %index% lss %count% goto while

:: ##############################################################
echo "All outputs have been written to %outputfile%"
PAUSE
exit