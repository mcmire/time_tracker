module TimeTracker
  module Extensions
    module MongoMapper
      module StateMachine
        class Error < StandardError; end
        class InvalidTransitionError < Error; end

        class TransitionCollection
          attr_reader :allowed_previous_states, :disallowed_previous_states

          def initialize(event, &block)
            @event = event
            @allowed_previous_states = []
            @disallowed_previous_states = {}
            # Evaluate in a module instead?
            instance_eval(&block) if block_given?
          end

          def allows(*states)
            @allowed_previous_states = states.map(&:to_s)
          end

          def disallows(*states_or_rules)
            if states_or_rules.size == 1 && Hash === states_or_rules[0]
              rules = states_or_rules[0]
              @disallowed_previous_states = rules.inject({}) {|h,(k,v)| h[k.to_s] = v; h }
            else
              states = states_or_rules
              @disallowed_previous_states = states.inject({}) {|h,s| h[s.to_s] = nil; h }
            end
          end

          def validate_transition_from!(previous_state)
            previous_state = previous_state.to_s
            if @allowed_previous_states.include?(previous_state)
              return true
            else
              msg = @disallowed_previous_states[previous_state] || "Can't go from #{previous_state.inspect} to #{@event.state.inspect}"
              raise InvalidTransitionError, msg
            end
          end
        end

        class Event
          attr_reader :state_machine, :name, :state, :transitions, :callbacks

          extend Forwardable
          def_delegators :transitions, :allowed_previous_states, :disallowed_previous_states

          def initialize(state_machine, name, &block)
            @state_machine = state_machine
            @name = name.to_s
            @transitions = nil
            @callbacks = {}
            # Evaluate in a module instead?
            instance_eval(&block) if block_given?
          end

          def sets_state(state)
            @state = state.to_s
          end

          def transitions(&block)
            @transitions = TransitionCollection.new(self, &block) if block_given?
            @transitions
          end

          def runs_callback(callback_type, &block)
            (@callbacks[callback_type] ||= []) << block
          end

          def validate_transition_from!(prev_state)
            @transitions.validate_transition_from!(prev_state)
          end

          def invalid_message_for_transition_from(prev_state)
            begin
              validate_transition_from!(prev_state)
              return
            rescue InvalidTransitionError => e
              return e.message
            end
          end

          def run_callbacks(model, callback_type)
            (@callbacks[callback_type] || []).each {|callback| callback.call(model) }
          end
        end

        class Machine
          attr_reader :model_class, :events, :transition_info

          def initialize(model_class, options={}, &block)
            @model_class = model_class
            @options = options
            @events = {}
            @transition_info = nil
            # Evaluate in a module instead?
            instance_eval(&block) if block_given?
          end

          def initial_state(state)
            state = state.to_s
            define_state_query_method(state)
            define_state_scope_methods(state)
          end

          def event(name, &block)
            event = Event.new(self, name, &block)
            @events[event.name] = event
            define_state_mutator_method(event.name)
            define_state_query_method(event.state)
            define_state_scope_methods(event.state)
          end

          def invalid_transition_message(current_state, next_event)
            @events[next_event].invalid_message_for_transition_from(current_state)
          end

          def start_transition!(model, current_state, next_event)
            current_state = current_state.to_s
            next_event = next_event.to_s
            event = @events[next_event]
            # assume that the transition was already validated earlier..
            @transition_info = {:event => event, :model => model}
          end

          def finish_transition
            @transition_info = nil
          end

          # A state machine for the state machine!
          def in_transition?
            !!@transition_info
          end

          def run_event_callbacks(callback_type)
            @transition_info[:event].run_callbacks(@transition_info[:model], callback_type)
          end

        private
          def define_state_mutator_method(name)
            model_class.class_eval <<-EOT, __FILE__, __LINE__
              def #{name}!                      # def stop!
                self.next_event = "#{name}"     #   self.next_event = "stop"
                save!                           #   save!
              end                               # end
            EOT
          end

          def define_state_query_method(state)
            model_class.class_eval <<-EOT, __FILE__, __LINE__
              def #{state}?                     # def stopped?
                state == #{state.inspect}       #   state == "stopped"
              end                               # end
            EOT
          end

          def define_state_scope_methods(state)
            model_class.class_eval do
              scope(state, where(:state => state))
              scope(:"not_#{state}", where(:state.ne => state))
            end
          end
        end

        module ClassMethods
          def state_machine(options={}, &block)
            if block_given?
              @state_machine = state_machine = Machine.new(self, options, &block)
              validate :validate_state_transition, :if => :transition_to_next_state?
              before_save :start_state_transition, :if => :transition_to_next_state?
              with_options :if => :state_in_transition? do |o|
                [:before_save, :before_create, :before_update, :after_update, :after_create, :after_save].each do |callback_type|
                  o.send(callback_type) { state_machine.run_event_callbacks(callback_type) }
                end
                o.before_save :save_next_state_as_new_state
                o.after_save :finish_state_transition
              end
              attr_accessor :next_event
            else
              @state_machine
            end
          end
        end

        module InstanceMethods
          # You signal that you want to go to the next state by setting next_state
          # to something different than it is now.
          def transition_to_next_state?
            !!@next_event
          end

          def state_in_transition?
            self.class.state_machine.in_transition?
          end

          def validate_state_transition
            if message = invalid_message_for_transition_to(@next_event)
              self.errors.add_to_base(message)
            end
          end

          def invalid_message_for_transition_to(next_event)
            self.class.state_machine.invalid_transition_message(self.state, next_event)
          end

          def start_state_transition
            self.class.state_machine.start_transition!(self, state, @next_event)
          end

          def save_next_state_as_new_state
            self.state = self.class.state_machine.transition_info[:event].state
          end

          def finish_state_transition
            self.class.state_machine.finish_transition
          end
        end
      end
    end
  end
end
