
# XXX: Why are we doing this exactly?

require 'term/ansicolor'

String.class_eval { include Term::ANSIColor }
