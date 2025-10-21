How To Use - 
1. Right click, Properties on both ps1 files, and tick Unblock
2. Edit source and destination root paths in File.ps1 or Folder.ps1, whichever you will use.
3. Add the list of file/folder paths (that you want to copy) to the log file for either FileIDs.log or FolderIDs.log
4. Run the ps1 file (FileCopy or FolderCopy, whichever fits your scenario).

NOTE: This is slower than using the AzCopy tool, but it is simpler and doesnt require details to connect to shares (assuming you already have them mapped in My Computer).
This is generic enough it can also be used for just copying files between Windows folders, so not neccessarily restricted to Azure Storage. 

Useful in the case you have thousands of files to copy out of a directory with millions of other files in it; saves you having to select out each file manually,
if you can programatically build a list of the specific file paths you need.