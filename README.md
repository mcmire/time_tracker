# time_tracker

How much time did you spend frobulizing the gazzlewonker just now? How many times have you been asked to make a report for the bossman or Joe in accounting this month?

time_tracker is a command-line utility that helps you answer these questions and, more importantly, keep your sanity.

I don't have everything nailed down yet but it's going to work something like this:

    > switch "acme widgets"
    Switched to project "acme widgets".
    > start "frobulize the gazzlewonker"
    Started clock for "frobulize the gazzlewonker".
    # Time passes...
    > finish
    Stopped clock for "frobulize the gazzlewonker", at 39m.
    > start "add a report for the bossman"
    Started clock for "add a report for the bossman".
    # Just then, the bossman tells you the site is down...
    > start "fix the site"
    (Pausing clock for "add a report for the bossman", at 1m.)
    Started clock for "fix the site".
    # ok, all done, let's get back to what we were doing!
    > finish
    Stopped clock for "fix the site", at 3h:39m.
    (Resuming clock for "add a report for the bossman".)
    # Time passes...
    # It's the end of the day. 
    # We didn't finish the report today, but let's see what we've been working on.
    > list today
    
    Today's tasks:
    
    9:30am - 9:39am: frobulize the gazzlewonker   [#1] (in acme widgets)
    9:39am - 9:40am: add a report for the bossman [#2] (in acme widgets)
    9:40am - 1:14pm: fix the site                 [#3] (in acme widgets)
    1:14pm -       : add a report for the bossman [#2] (in acme widgets)
    

What that demo doesn't show is the ability to tag tasks, which is always very helpful.

But one of the ways it will differ from other time-tracking tools is the ability to "up-vote" a task. So if Joe from accounting asked you about creating that report today but this is the 5th time he's done this, you can record this information. This will help you to prioritize tasks.

Since I don't like forcing people to abandon the tools they're already using, one of the things I'm planning to add is integration with other tools, such as Pivotal Tracker, Freckle, or even git (using a hook or something).

I'm also considering a web frontend, although that may come further down the line.

## Similar projects

* <http://github.com/ymendel/one_inch_punch>
* <http://github.com/samg/timetrap>