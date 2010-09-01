* Pivotal Tracker integration

  unstarted -> started -> stopped -> completed -> ( staged -> ) committed
                  ^         |
                   \________/

  * Flesh out config command - tt config external_service pivotal --api-key xxxx --full-name "Joe Bloe"
  * Add a "completed" state, and a "finish" command that stops the task and marks it as completed 
    * When a feature is finished, send accepted + delivered to PT, or completed if that's all that necessary
  * Remove "paused" state; disallow a completed task to be resumed
* Modify add task (and auto-adding before starting) to search before adding a new one, and suggest pre-existing tasks to up-vote instead
* Sort lists by number of votes
* Modify search command so it says "no tasks found" if no tasks found
  * Also modify search results list so it's consistent w/ other listings
* Feature: Manual mass-editing
  * This will allow tasks to be reprioritized
  * Maybe make it possible to edit only a portion of the list, say, tasks tagged with X or just from today or something?
  * Maybe do it in the style of `git rebase` -- pipe to less, rearrange the list as necessary, resave
* Feature: Tagging
  * tt tag "some task" #this #and #that
  * Might need to tweak listings again
* Feature: Task comments
  * Modify manual mass-editing to pick up comments (bulleted list indented under a task)
  * tt add comment "some task" "Your mom and things" (or pipe in a comment)
  * Collapse all comments as one PT description field
* Feature: Marking a task as staged
  * tt stage "some task"
* Feature: Git hook (storing git id w/ a task to mark it as committed)
  * Maybe you can also say `tt commit "some task"`
* Feature: 'show' command (list everything about a task - tags, comments, etc.)
* Add colors to listings
* tt help COMMAND

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
* Pipe listings to less?
* Feature: Pause (put on hold, hold, suspend) a task manually?
* Since MongoDB's natural sort order is not often desirable, are there other cases in which we aren't ordering by something explicit? Or is there a way to hack MM to sort by created_at by default?
* List today's tasks by ended_at asc too?