# TimeTracker

How much time did you spend frobulizing the gazzlewonker just now? How many times have you been asked to make a report for the bossman or Joe in accounting this month?

TimeTracker is a command-line utility that helps you answer these questions and, more importantly, keep your sanity.

## How it'll work

I don't have everything nailed down yet, but here's a quick little demo.

So let's say you've come into the office, had your morning coffee, and you're ready to start working. Let's just fire up TimeTracker:

    $ tt
    Welcome to TimeTracker.
    It looks like you were working on the "acme widgets" project last time.

After you've read your email, your first task is to start frobulizing the gazzlewonker. So let's tell TimeTracker about that:

    > start "frobulize the gazzlewonker"
    Started clock for "frobulize the gazzlewonker".

Okay, great. That's a little task so it doesn't take you that long to do.

    > finish
    Stopped clock for "frobulize the gazzlewonker", at 39m.

Next, the bossman asks you to make a report, so you start on that:

    > start "add a report for the bossman"
    Started clock for "add a report for the bossman".

Just then, you find out that one of your clients' sites is down! No worries, TimeTracker is smart enough to pause the clock on the current task before starting on the new one:

    > start "fix the site"
    (Pausing clock for "add a report for the bossman", at 1m.)
    Started clock for "fix the site".

Well, that took a while, but finally the site's back up. What were we working on before?? Oh right, making a report:

    > finish
    Stopped clock for "fix the site", at 3h:39m.
    (Resuming clock for "add a report for the bossman".)
    
Before we know it, it's the end of the day. Guess the bossman's going to have to wait for that report -- we didn't get done with it today. What took up our time? Let's just find out:
    
    > list today
    
    Today's tasks:
    
     8:30am -  9:39am [#1] acme widgets / frobulize the gazzlewonker
     9:39am -  9:40am [#2] acme widgets / add a report for the bossman
     9:40am - 12:14pm [#3] pete's popsicles / fix the site
    12:14pm -         [#2] acme widgets / add a report for the bossman
    

So that's kind of how it'll work.

## Upcoming

What that demo doesn't show is the ability to tag tasks, which is always very helpful.

But one of the ways it will differ from other time-tracking tools is the ability to "up-vote" a task. So if Joe from accounting asked you about creating that report today but this is the 5th time he's done this, you can record this information. This will help you to prioritize tasks.

Since I don't like forcing people to abandon the tools they're already using, one of the things I'm planning to add is integration with other tools, such as Pivotal Tracker, Freckle, or even git (using a hook or something).

I'm also considering a web frontend, although that may come further down the line.

## Similar projects

* <http://github.com/ymendel/one_inch_punch>
* <http://github.com/samg/timetrap>