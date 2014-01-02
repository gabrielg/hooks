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
    #
    # If <tt>:around</tt> is enabled:
    #
    #   class Person
    #     define_hook :around_eating, :around => true
    #
    #     around_eating :be_hygienic
    #
    #     def be_hygienic
    #       wash_hands
    #       yield
    #       do_dishes
    #     end
    #   end
    #
    def run(scope, *args, &block)
      raise ArgumentError, "A block is required" if around_callback? && !block_given?
      block = around_block(block) if around_callback?

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
        args << block if block_given?
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

    def around_callback?
      @options[:around] == true
    end

    def around_block(block)
      call_count = length - 1

      lambda do
        next(block.call) if call_count == 0
        call_count -= 1
      end
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
