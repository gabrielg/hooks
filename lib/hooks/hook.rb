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
      return yield if around_callback? && empty?

      results = Results.new
      enumerator = to_enum(:each_with_index) { length }

      iterator = proc do
        callback, idx = enumerator.next

        passed_block =
          case
          when around_callback? && last_callback?(idx) then block
          when around_callback? then iterator
          when block_given? then block
          end

        executed = execute_callback(scope, callback, *args, &passed_block)
        return results.halted! unless continue_execution?(executed)
        results << executed
      end

      if around_callback?
        iterator.call
      else
        iterator.call while true
      end

      return results
    rescue StopIteration
      return results
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

    def last_callback?(callback_index)
      length - 1 == callback_index
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
