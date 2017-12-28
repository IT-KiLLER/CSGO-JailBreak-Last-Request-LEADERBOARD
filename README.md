# [CS:GO] JailBreak/Last-Request: LEADERBOARD
An addons to SM Hosties. A top list for LR players.

![screenshot 1](https://image.ibb.co/hmdwZw/lrtop1.jpg)
![screenshot 2](https://image.ibb.co/gOFM1b/lrtop2.jpg)

## Commands
  - `!lrtop` - *_Leaderboard menu._*
  - `!clearlrtop` - *_Emptying the leaderboard (ONLY SERVER)._*
  
## Requires
- [SM_Hosties v2](https://forums.alliedmods.net/showthread.php?t=108810) (Yes because this is an addons)

## Installation (EASY)
 1. Open `addons\sourcemod\configs\databases.cfg`
 2. Add this:
```
"lr-leaderboard"
{
     "driver"   "sqlite"
     "host      "localhost"
     "database" "lr-leaderboard-sqlite"
     "user"     "root"
     "pass"     ""
}
 ```
3. Place the plugin `LR_LEADERBORAD.smx` as usual in the plugins folder.
4. Change map. (Some may need to reload the plugin again).

**DONE!**

If the above does not work. Please be sure to restart the server.

## Download
### [Download (smx)](https://github.com/IT-KiLLER/CSGO-JailBreak-Last-Request-LEADERBOARD/raw/master/LR_LEADERBORAD.smx)    [Source code (zip)](https://github.com/IT-KiLLER/CSGO-JailBreak-Last-Request-LEADERBOARD/archive/master.zip)
Please feel free to contact me if you have any questions. [contact information here.](https://github.com/IT-KiLLER/HOW-TO-CONTACT-ME)

Thanks to Nick @ GFL for code review and testning.

## Database schema (Just information)
```
CREATE TABLE IF NOT EXISTS leaderboard (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(64) NOT NULL DEFAULT ' ',
    steamid varchar(64) NOT NULL UNIQUE,
    eligible_lr INTEGER DEFAULT '0',
    start_lr INTEGER DEFAULT '0',
    won_lr INTEGER DEFAULT '0',
    most_lr INTEGER DEFAULT '0',
    guards_beaten INTEGER DEFAULT '0'
);
```

## Change log
- **1.0** - 2017-11-26
  - Release!
