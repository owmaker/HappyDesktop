# Happy Desktop

### Program Requirements: ####

This program is used to save/restore/align the Ubuntu and Mint Desktop icons
positions when Nautilus, Nemo, or Caja is managing the desktop.
This version has been tested with:  
    Mint 22.1 Mate with Caja
       
Requirements:  
    gio which is used by Nautilus, Nemo & Caja to store icon positions  
    Nautilus or Nemo or Caja is your file manager  
    bash, zenity, gsettings, xprop, sed, grep  


### Installation Instructions  ####

1. Copy the three files:  
		Happy_Desktop.sh  
		Happy_Desktop.png  
		happy_desktop.lang  

 	to either your bin or nautilus scripts folder or subfolder with name of your choice:  
        (/home/YourUserName/bin) or  
        (/home/YourUserName/.local/share/nautilus/scripts) or  
        (/home/YourUserName/bin/anysubfolder) or  
        (/home/YourUserName/.local/share/nautilus/scripts/anysubfolder)  


### Initial Setup ####

1. During initial run of the script, you will be asked to enter the "icons per row" and icons per column" you want for your desktop. These two variables determines how the icon grid alignment function will work for the program.  For example, if you enter "10" for "icons per column", this means that program will calculate an icon row "height" that allows for 10 equally spaced rows for each column.  Similarly, the "icons per row" setting allows the program to calculate the icon column "width" for each icon in a row. So, prior to running the script, determine how many "icons per row" and "icons per column" you want.  If you decide later to change the setting, it can be accomplished throught the configuration menu.

2. Run the script. 
    a). If you copied the "happy_desktop.lang" file, you will be asked to select your language.
    b). Input the "icons per column" and "icons per row" values that you desire.
    c). You will be given the option to create a desktop icon to launch Happy Desktop the first time you run the script. You can always delete the desktop icon later if you desire to run the script directly.  

3. On the first run, two files will be created in the installation directory:

      happy_desktop.ini   (where your preferences are saved)  
      happy_desktop_restore.db   (used to restore icon positions)

### Using the Program ####

1. Use "Save Current Icon Positions" to save the current icon positions to file (happy_desktop_restore.dat)

2. Use "Restore Icon Positions" to reposition icons on the desktop using the data from the "happy_desktop_restore.dat" file

3. Use "Undo last operation" to "undo" the last restore operation.

### Using the Grid Function ####

1. Use "Save Icon Positions to Grid" to automatically move icons left/right/up/down to the nearest grid lines as defined by your initial "icons per row" and "icons per column" settings.  This will perfectly align icons in rows and columns.

2. Use "Undo last operation" to "undo" the last "Save Icon Positions to Grid" operation.

3. During initial "Save Icon Positions to Grid" it is normal that some adjacent icons may be moved to the same positions and then be overlapping.  Use "Disintangle Overlapping Icons" to automatically separate these icons.  Then move the icons to an open row or position of your liking and "Save Icon Positions to Grid" again.

4. To "fine tune" the grid layout, go into "Configuration" and change the "Left Margin", "Top Margin", "Grid Width", and "Grid Height" to modify the layout to your preference.

### Notes ####

   Note: The "System Icons" (Computer, Home Folder, Trash, Network Servers, Mounted Volumes) can not be modified or controlled by "Happy Desktop".  However, by adjusting the margins and grid values, you can align the user desktop files/folders to the system icons (if you desire).

   Note: The "Icons Per Row" and "Icons per column" values are only used to determine initial grid values.  After that, the margins and grid dimensions control the layout. Changing the "Icons Per Row" and "Icons per column" again will also change the grid dimensions (but not the margins).

   Note: This program uses your screen resolution and the "default icon zoom" (under Nautilus\preferences) to determine the initial grid size.  Changing either the screen resolution or "default icon zoom" will require the repeat of the initial setup.

   Note: This version of Happy Desktop no longer requires "xdotool" to position the icons.


### Language Translations ####

 Happy Desktop supports a multilanguage interface by using the file "happy_desktop_lang.  To add support for your language, just add your translations to "happy_desktop_lang". Your new language will automatically appear as an option in the language configuration menu.  If you do not need multilanguage support, you can erase the "happy_desktop_lang" file.

### Creating a desktop icon  ####

1. The program will prompt you to create a desktop icon to launch the application on the first script run.  If you did not create a desktop icon on the first script run, you can delete the file "Happy_Desktop.ini" and then the next time you run the script it will prompt you again to create the desktop launch icon.

### Copyright ###

Original script by:

    copyright © 2017 retiredbutstillhavingfun

    Happy Desktop  
    Version 2.00  
    10OCT2017  
    drm200@free.fr  
    GNU General Public License v2.0  
