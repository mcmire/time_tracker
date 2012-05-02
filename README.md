# TimeTracker

How much time did you spend frobulizing the gazzlewonker just now? How many times have you been asked to make a report for the bossman or Joe in accounting this month?

TimeTracker is a command-line utility that helps you answer these questions and, more importantly, keep your sanity.

## A quick demo

So let's say you've come into the office, had your morning coffee, and you're ready to start working. Let's just fire up TimeTracker:

    $ tt
    Welcome to TimeTracker.
    It looks like you were working on the "acme widgets" project last time.
    What do you want to do?
    >

The first thing you're going to tackle this morning is to frobulize the gazzlewonker. So let's tell TimeTracker about that:

    > start "frobulize the gazzlewonker"
    Started clock for "frobulize the gazzlewonker".

It's a tiny task so it doesn't take you that long to do.

    > finish
    Stopped clock for "frobulize the gazzlewonker", at 39m.

Next, the bossman asks you to make a report, so you start on that:

    > start "add a report for the bossman"
    Started clock for "add a report for the bossman".

Just then, you find out that one of your clients' sites is down! No worries, TimeTracker is smart enough to pause the clock on the current task before starting on the new one:

    > start "fix the site"
    (Pausing clock for "add a report for the bossman", at 1m.)
    Started clock for "fix the site".

Whew! That took a while, but the site's finally back up. What were we working on again? Oh right, making a report:

    > finish
    Stopped clock for "fix the site", at 3h:39m.
    (Resuming clock for "add a report for the bossman".)

Before we know it, it's the end of the day. Guess the bossman's going to have to wait till tomorrow to see that report. So what took up our time today, anyway? Let's just find out:

    > list today

    Today's tasks:

    12:14pm -         [#2] acme widgets / add a report for the bossman
     9:40am -  1:19pm [#3] pete's popsicles / fix the site
     9:39am -  9:40am [#2] acme widgets / add a report for the bossman
     9:00am -  9:39am [#1] acme widgets / frobulize the gazzlewonker

## Present features

TimeTracker is still a work in progress, but here are the sorts of things it can do right now:

* Add a new project (`tt add project "some project"`)
* Switch to an existing project (`tt switch "some project"`)
* Add a new task within a project (`tt add task "some task"`)
* Start a task (`tt start "some task"`)
* Mark a task as finished (`tt finish "some task"`)
* Resume a paused task (`tt resume "some task"`)
* Show the last few tasks (`tt list lastfew`)
* Show today's tasks (`tt list today`)
* Show this week's tasks (`tt list this week`)
* Show finished tasks (`tt list finished`)
* Show all tasks (`tt list all`)
* Search for a task (`tt search "search text"`)
* Upvote a task (`tt upvote "some task"`)

<!--
Additionally, TimeTracker has support for pushing and pulling updates to and from Pivotal Tracker. To set this up, you first have to tell TimeTracker your api key and name:

    tt configure external_service pivotal --api-key xxxx --full-name "Joe Bloe"

Now, when you add a project or task to TimeTracker, it will add the project or task to your account on Pivotal Tracker. ...
-->

`tt` incurs a bit of startup time, so if you're launching it over and over again it can get a little annoying. Fortunately, if you just say `tt`, you'll be put into a TimeTracker session with a prompt. You type commands just like you normally would, except you just leave out "tt". (This is shown off in the demo, above.)

## Upcoming features

Here are some of the things I've planned:

* **Tagging.** So you'd be able to say something like `tt tag "some task" #from:joe #cc:pete #accounting`. Then, you'd be able to pull up a list of tasks by tag.

* **Upvoting.** This is one of the ways TimeTracker will differ from other time-tracking tools. So if Joe from accounting asked you about creating that report today but this is the 5th time he's done this, you can record this information. This will help you to better prioritize tasks going forward.

* **Integration with other services.** If you're using something like Pivotal Tracker or Freckle, you might as well be able to push changes to these services from the command line. (And if you're offline, no worries -- you'd be able to sync changes the next time you're online.)

* **Task comments.** This would imply a concept of users or authors, but you'd be able to say something like `tt add comment "some task" "This is a great idea"` and it would show up in a bulleted list under the task when it's displayed.

* **Mass editing.** Perhaps (similar to `git rebase`) a representation of all your tasks would get piped to your editor, and you could edit them or perform actions on them all at once.

* **A web frontend**... since sometimes the command line just ain't enough.

I'm also considering a web frontend, although that may come further down the line.

## Neat! How do I try it out?

First, TimeTracker stores data locally in a MongoDB database. So you'll need to install that on your computer. Fortunately it's super easy -- just go to <http://www.mongodb.org/downloads> and download the latest production release (1.6.5 as of this writing) for your platform. Extract the tarball somewhere (say, /opt/mongo). Then, run `sudo /opt/mongo/bin/mongod --dbpath /data/db run &>/dev/null &` to start the database server. (Maybe you want to put this in a shell script.)

Now for TimeTracker itself. Ideally it would be a gem, but I'm not to that point yet, so you'll have to get it straight from the githubs:

    git clone http://github.com/mcmire/time_tracker.git
    cd time_tracker

Now you'll want to install the gem dependencies. (If you use RVM, I have a .rvmrc so you should be in a custom gemset.)

    bundle install --without test

Now you should be able to say:

    bin/tt --help

## Something is borked!

I keep issues in [Issues](http://github.com/mcmire/time_tracker/issues), so issue away and I'll take a look. If you feel like taking the time to submit a pull request, even better. (See below on development.)

## TimeTracker is great, but I'd like to use it this way...

Seriously, if you have ideas, just ping me (my contact info is at the bottom).

## Anything I need to know when hacking on it?

There are tests in spec/. I've made sure these are up to date, you should too. Presently, I'm using a gem I wrote called [ribeye](http://github.com/mcmire/ribeye) to simulate interaction with the command line, although since I've basically abandoned that project, I need to extract the CLI stuff out. But for now that's what I'm using.

## Can I help out?

Sure! Right now I've got a to-do list under [TODO.md](https://github.com/mcmire/time_tracker/blob/master/TODO.md). PM or email me and we'll talk.

## Similar projects

There are a couple I've found:

* <http://github.com/ymendel/one_inch_punch>
* <http://github.com/samg/timetrap>

## Author/Contact

This project is (c) 2010-2011 Elliot Winkler. If you have any questions, please
feel free to contact me through these channels:

* **Twitter**: [@mcmire](http://twitter.com/mcmire)
* **Email**: <elliot.winkler@gmail.com>
* (And, of course, on the githubs)

## License

All code here is free to use for personal and commercial purposes. If you learn
something from it, awesome. If it powers your multi-million dollar enterprise,
even better. If it gets put in a computer on a rocket to Mars, fantastic. I'm
not going to sue you, I really don't care. You don't even have to attach a
courtesy if you don't want (though it's the neighborly thing to do). Basically,
use your powers wisely, and above all, be nice!
