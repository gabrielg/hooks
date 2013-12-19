module Hooks
  class Hook < Array
    def initialize(options)
      super()
      @options = options
    end

    # The chain contains the return values of the executed callbacks.
    #
    # Example:
    #
    #   class Person
    #     define_hook :before_eating
    #
    #     before_eating :wash_hands
    #     before_eating :locate_food
    #     before_eating :sit_down
    #
    #     def wash_hands; :washed_hands; end
    #     def locate_food; :located_food; false; end
    #     def sit_down; :sat_down; end
    #   end
    #
    #   result = person.run_hook(:before_eating)
    #   result.chain #=> [:washed_hands, false, :sat_down]
    #
    # If <tt>:halts_on_falsey</tt> is enabled:
    #
    #   class Person
    #     define_hook :before_eating, :halts_on_falsey => true
    #     # ...
    #   end
    #
    #   result = person.run_hook(:before_eating)
    #   result.chain #=> [:washed_hands]
    def run(scope, *args, &block)
      inject(Results.new) do |results, callback|
        executed = execute_callback(scope, callback, *args, &block)

        return results.halted! unless continue_execution?(executed)
        results << executed
      end
    end

  private
    def execute_callback(scope, callback, *args, &block)
      case callback
      when Symbol then
        scope.send(callback, *args, &block)
      when Proc then
        # TODO: Allow for passing a block in to instance_execed callbacks.
        scope.instance_exec(*args, &callback)
      else
        callback.send(name, scope, *args, &block)
      end
    end

    def continue_execution?(result)
      @options[:halts_on_falsey] ? result : true
    end

    def name
      @options[:name]
    end

    class Results < Array
      # so much code for nothing...
      def initialize(*)
        super
        @halted = false
      end

      def halted!
        @halted = true
        self
      end

      # Returns true or false based on whether all callbacks
      # in the hook chain were successfully executed.
      def halted?
        @halted
      end

      def not_halted?
        not @halted
      end
    end
  end
end
