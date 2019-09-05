# WBADminOfflineBackup

I am by no means endorsing this over a legitimate backup solution, but as many of you know, sometimes you have to do the best you can with what you're given.

This script will: 
  1. Mount a volume you define by providing it the GUID of the drive in the $VolumeID variable.
  2. Close open SMB files based on the files path name and a filter you provide.
  3. Start WBAdmin and perform a full image backup to the previously mounted volume and wait for the WBAdmin process to complete before        proceeding.
  4. Check for backups older than a number of days you provide in $RetentionDays and delete any that it finds
  5. Safely ejects the volume
  6. Logs all of the above steps and their results to a $LogResult variable, which it then exports to a file and emails to an address of        your choosing.
  7. As much error handling and validation as could be incorporated.
  
In this way, the volume containing the backup data is only accessible via the OS during the actual backup window. The entire process is completely automated via a Scheduled Task.
