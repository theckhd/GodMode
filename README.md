# GodMode
This SWL Addon provides a text indicator showing when the Auto-Loader bug has been triggered. 

![Indicator](screens/Indicator.PNG) 

The indicator can be customized in a number of ways:
- It can be moved in GUI edit mode (using the lock symbol at the top right of the screen).
- The text can be changed using `/setoption gm_text "XXXXX"` (default "GM") where `XXXXX` is the new text you want it to display
- The font size can be changed using `/setoption gm_fontsize XX` (default 30)
- The font color can be changed using `/setoption gm_color 0xYYYYYY` (default 0xFFCC00), where YYYYYY must be a six-digit hex code for the color you want. There are a variety of good <a href="https://www.w3schools.com/colors/colors_picker.asp">HTML color code websites</a> to choose from.

In addition, the addon collects statistics about the grenade proc rate for both states (with and without God Mode active). You can enable reporting of stats using the following commands:
- `/setoption gm_stats true` (default false) will enable a report for the current encounter.
- `/setoption gm_stats_all true` (default false) will enable an overall report for the entire play session (since the last /reloadui). 
Note that these can get pretty spammy if you enable both.
