## Carbon Copy Cloner 6+ Report Scripts

This directory contains two scripts for reporting CCC backup status to Healthchecks instance. 


### FAQ
1. **How do I use it with CCC?**
First, you probably should read [CCC docs first](https://bombich.com/it/kb/ccc6/performing-actions-before-and-after-backup-task)
to get an idea of precise configuration options of CCC itself in regard to scripts.

Then copy scripts from the repo to some folder (e.g. `/Users/<yourUser>/Scripts/CCC/<myTaskName>`). Next, edit both 
scripts and set at minimum `PING_URL` in both. Finally, set both scripts accordingly as Preflight => Shell Script and 
Postflight => Shell Script.

2. **Can it be done with one script?**
Not really. As of the time of writing CCC doesn't provide any "action" or "state" via either parameters nor environment
variables. Thus, it's impossible to reliably distinguish pre- from post-flight calls.

3. **Some information is logged twice?!**
This is on purpose. In case you fat-finger setting the scripts you want to know in your monitoring system that something
is wonky. The last thing you want is to accidentally report wrong job status and learn about it 2 months later ;)
*ask me how I know...*

4. **Can I use one set of pre- and post-flight scripts instead of per-task basis?**
Nope. [CCC at the time of writing](https://bombich.com/it/kb/ccc6/performing-actions-before-and-after-backup-task) 
doesn't provide any way to distinguish tasks in scripts.
