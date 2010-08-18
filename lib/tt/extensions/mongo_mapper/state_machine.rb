module TimeTracker
  module Extensions
    module MongoMapper
      module StateMachine
        class Error < StandardError; end
        
        class Event
          attr_reader :machine, :name, :state, :allowed_previous_states, :callbacks
          
          def initialize(machine, name, &block)
            @machine = machine
            @name = name.to_s
            @allowed_previous_states = []
            @callbacks = {}
            instance_eval(&block) if block_given?
          end
          
          def sets_state(state)
            @state = state.to_s
          end
          
          def transitions_from(*states)
            @allowed_previous_states += states.map(&:to_s)
          end
          
          def runs_callback(callback_type, &block)
            (@callbacks[callback_type] ||= []) << block
          end
          
          def can_transition_from?(prev_state)
            allowed_previous_states.include?(prev_state)
          end
          
          def run_callbacks(model, callback_type)
            (@callbacks[callback_type] || []).each {|callback| callback.call(model) }
          end
        end
        
        class Machine
          attr_reader :model_class, :events
          
          def initialize(model_class, options={}, &block)
            @model_class = model_class
            @options = options
            if options[:initial]
              define_state_query_method(options[:initial].to_s)
              define_state_scope_methods(options[:initial].to_s)
            end
            @events = {}
            @transition_info = nil
            instance_eval(&block) if block_given?
          end
          
          def event(name, &block)
            event = Event.new(self, name, &block)
            (@events[event.state] ||= []) << event
            define_state_mutator_method(event.name, event.state)
            define_state_query_method(event.state)
            define_state_scope_methods(event.state)
          end
          
          def start_transition!(model, current_state, next_state)
            current_state = current_state.to_s
            next_state = next_state.to_s
            event = @events[next_state].find {|event| event.can_transition_from?(current_state) }
            raise "Can't go from #{current_state.inspect} to #{next_state.inspect}!" unless event
            @transition_info = {:event => event, :model => model}
          end
          
          def finish_transition
            @transition_info = nil
          end
          
          def in_transition?
            !!@transition_info
          end
          
          def run_event_callbacks(callback_type)
            @transition_info[:event].run_callbacks(@transition_info[:model], callback_type)
          end
          
        private
          def define_state_mutator_method(name, state)
            model_class.class_eval <<-EOT, __FILE__, __LINE__
              def #{name}!                             # def stop!
                self.next_state = #{state.inspect}     #   self.next_state = "stopped"
                save!                                  #   save!
              end                                      # end
            EOT
          end
          
          def define_state_query_method(state)
            model_class.class_eval <<-EOT, __FILE__, __LINE__
              def #{state}?                            # def stopped?
                state == #{state.inspect}              #   state == "stopped"
              end                                      # end
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
          def machine; @machine; end
          
          def state_machine(options={}, &block)
            @machine = machine = Machine.new(self, options, &block)
            # Hook into MongoMapper callbacks so that we can access the value of created_at
            # in a transition callback.
            ## Use both create and update in case model defines before_save's that need to happen
            ## before this callback, such as copying created_at to another variable.
            before_save :start_state_transition, :if => :transition_to_next_state?
            with_options :if => :state_in_transition? do |o|
              [:before_save, :before_create, :before_update, :after_update, :after_create, :after_save].each do |callback_type|
                o.send(callback_type) { machine.run_event_callbacks(callback_type) }
              end
              o.before_save :save_next_state_as_new_state
              o.after_save :finish_state_transition
            end
            attr_accessor :next_state
          end
        end
        
        module InstanceMethods        
          # You signal that you want to go to the next state by setting next_state
          # to something different than it is now.
          def transition_to_next_state?
            next_state && next_state != state
          end
          
          def state_in_transition?
            self.class.machine.in_transition?
          end
          
          def start_state_transition
            self.class.machine.start_transition!(self, state, next_state)
          end
          
          def save_next_state_as_new_state
            self.state = next_state
          end
          
          def finish_state_transition
            self.class.machine.finish_transition
          end
        end
      end
    end
  end
end