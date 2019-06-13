# Object Clutter - Could lead to performance issues.

Interested in clearing out some cruft from your Jamf Pro server? Want to find some things that could be causing performance issues? 

The following script(s) will run some basic queries against the database to identify a variety of problematic objects. They will output a .txt including some notes on what the query was, and why it's of interest. Hopefully this will allow you to trim the fat, or whatever else your heart desires. 

The .bash script will run on macOS/Linux, the .bat script is for Windows. Unfortunately, this won't work if you're cloud hosted. Buuuut you might be able to submit a support ticket to get the script run ;) 

## Instructions
### macOS/Linux
1. Copy object_queries.bash to the MySQL server.
1. Run the script -
    1. To run the script on macOS open Terminal and type in "sudo bash ", then drag the script from its current location into Terminal.
    1. To run the script on Linux type in "sudo bash " followed by the file path to object_queries.bash and hit enter.
1. The client will be prompted for the following information -
    * Operating System - Enter 1 for Linux and 2 for macOS.
    * MySQL Username - This can be the root user or the jamfsoftware user.
    * MySQL Password - Password for the chosen user.
    * Database Name - Enter the name of the database (typically jamfsoftware).
    * Location of MySQL - The default location will be provided as an example, just hit return to use that. If a different location is used, enter the full path to the MySQL binary.
1. The script outputs a file that is dependent on the operating system - 
    1. For Linux, the file is output to /tmp/object_queries.txt.
    1. For macOS, the file is output to /Users/Shared/object_queries.txt.


### Windows
1. Copy object_queries.bat to the desktop of the MySql server.
1. Run the script by double-clicking the file.
1. The client will be prompted for the following information -
    * MySQL Username - This can be the root user or the database user.
    * MySQL Password - Password for the chosen user.
    * Database Name - Enter the name of the database (typically jamfsoftware).
    * MySQL version - Use only the major and minor numbers - Ex: 5.7.
1. The script outputs a file to C:\object_queries.txt.
