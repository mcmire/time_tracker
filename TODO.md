* Plug into Highline
* Integrate with Pivotal
  * stop -> finish/end/complete, start -> begin (change error messages too)
  * There are quite a few command-line clients we can borrow code from:
    * http://github.com/Neurogami/pivotal_slacker
    * http://github.com/joshsz/pivotal_attribution
    * http://github.com/hone/git_pivot
    * http://github.com/coreyti/pt-console
    * http://github.com/chrisgibson/pivot
  * Three ways of doing this
    1. Completely manual - if a task is added or updated, we queue the change and then when we say "push", all changes are executed on the server. If a change can't be made (b/c the task was deleted, for instance) then it's marked as invalid and skipped. When we say "pull", we basically have to go through each id on the server and compare with the corresponding record in our database. The downside is, we have to pull ALL data from the server EVERY TIME in order to do that, and I don't think there's an efficient way to do this.
    2. Update on demand - when we say, e.g. `tt list` then hit the XML feed. As soon as info is added to a task that Tracker doesn't store (time periods, multiple comments, number of votes) we create a record in the db with Tracker's task id and the relevant info. Downside is that if a task is deleted from Tracker's interface, it will make our record an orphan. Or, if the task has been updated on Tracker since we worked with it last, the data will be out of sync. So in order to combat this, we need to hit the XML feed and update the task before we work with a task.   
    * Actually, when we do anything that involves multiple tasks (listing, searching) we need to do a comparison similar to how we would do with the push/pull model in case any new tasks have been added or existing ones have been changed. Furthermore, the list we pull from the API has to be filtered, and the filter depends on what we're doing at the time. So if we say `tt list today`, then we only pull tasks updated today, and compare the ids to the ids already in the system. If we say `tt list completed` then we pull completed tasks, and do the same thing.
    * Actually when we switch to a project, we need to hit the API and ensure the project name hasn't been changed or the project hasn't been archived, or anything
  * Add `config use pivotal` subcommand that lets user turn on Pivotal integration mode. It will ask user for api token / username / password, in an interactive prompt - stored in the `config` collection
    * Naturally, if user wants to switch back for any reason, they can say `config no pivotal`.
    * Maybe we should make it impossible for someone to switch to another integration option if they already have data?
    * Or maybe the first time they use `tt`, say "It looks like this is your first time using TimeTracker. We need to know a few things from you before you can get busy."
  * Add a "type" attribute for bug, feature, chore
  * States for Pivotal tasks: unscheduled, unstarted, started, finished, delivered, accepted, rejected
  * This is how those map:
    * unscheduled - This is when a task is in the icebox and hasn't been moved into current or backlog yet
    * unstarted - The task is in current or backlog but hasn't been started yet. "created" becomes this.
    * started - Same
    * assigned - Not really a state, but a task must be assigned before it can be started. This is automatic though -- if a task is started without an owner, we might as well automatically assign it.
    * finished - "stopped" becomes this.
    * delivered/accepted/rejected - These aren't really necessary to store. If a feature is marked as complete, can we tell Tracker to accept + deliver it?
  * I want to add two more states: "staged" and "committed". A task is actually complete when it's committed, and once committed, the task's state can't be changed (this is actually different from Tracker). "staged" is a state that comes before "committed", but is optional.
  * So to recap it goes like this:
  
    unstarted -> started -> finished -----------> committed
                                    \             /
                                     `-> staged -'

  * add project
    * adds the project to PT, then TT
  * add task
    * adds the task to PT, then TT
  * switch
    * hits PT, pulls the project's name, then updates the current project in TT
    * when the running task is paused we need to hit the API first and make sure the task is still there
    * when the paused task is resumed we need to do the same thing
  * start
    * when the running task is paused we need to hit the API first and make sure the task is still there
    * if the task is created, adds the task to PT, then TT
  * stop
    * when the task is stopped we need to hit the API first and make sure the task is still there
    * when the last paused task is resumed we need to hit the API first and make sure the task is still there
  * resume
    * when the last running task is paused we need to hit the API first and make sure the task is still there
    * when the task is resumed we need to hit the API first and make sure the task is still there
  * upvote
    * when the task is upvoted we need to hit the API first and make sure the task is still there
  * list
    * on lastfew, pull the last 5 tasks from PT and then merge them in with local db before displaying
    * the problem is that the last 5 tasks on PT may not be the last 5 in the local db, so how do we combat this? by pulling all tasks from PT that have been created/modified since we last pulled. this won't handle the case in which tasks have been deleted from PT but not TT. we will handle these individually

  * What about `add task` where we check to see if the task already exists? If we are out of sync with what's on PT, then we could create a duplicate task that we'll have to remove from TT later.
    * Would it be easier to always pull the latest modified tasks from PT every command? (and handle deleted tasks individually) -- Yes, this shouldn't be slow.

* tt.external_service
  * test out some path
  * get latest tasks within a project
  * get one task

* Flesh out config command - tt config external_service pivotal --api-key xxxx --full-name "Joe Bloe"
* Disallow a stopped task to be resumed
* Modify add task (and auto-adding before starting) to search before adding a new one, and suggest pre-existing tasks to up-vote instead
* Sort lists by number of votes
* Modify search command so it says "no tasks found" if no tasks found
* Feature: Move a task up or down on the list
* Feature: Tagging
  * Might need to tweak listings again
* Feature: Comments on tasks
* Feature: Marking a task as staged
* Feature: Git integration (storing git id w/ a task to mark it as committed)
* Feature: 'show' command (list everything about a task - tags, comments, etc.)
* Add colors to listings
* Command-line UI, so that we can "stick" the prompt for commands at the
  top of the terminal window and then if the user runs, say, `tt list`
  and the list is really long, the user doesn't lose their place
  * ncurses
    * <http://raggle.org/about/>
    * <http://github.com/laurynasl/rubyrogue>
    * <http://github.com/zdennis/ncurses_examples>
  * nfoiled: <http://github.com/elliottcable/nfoiled>
    * <http://github.com/elliottcable/rat>
  * termbox: <http://github.com/nsf/termbox> - wish there were a ruby interface!
  * luck: <http://github.com/danopia/luck> - I like!!
    * <http://github.com/danopia/remora>
* Pipe listings to less

* Feature: Pause (put on hold, hold, suspend) a task manually?
* Since MongoDB's natural sort order is not often desirable, are there other cases in which we aren't ordering by something explicit? Or is there a way to hack MM to sort by created_at by default?
* List today's tasks by ended_at asc too?