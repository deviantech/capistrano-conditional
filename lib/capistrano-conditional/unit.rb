module Capistrano
  module Conditional
    # Stores the actual conditionals added by the user, including under
    # what conditions the conditional should be applied (<em>conditions</em>)
    # and what to do if that's the case (<em>block</em>).
    #
    # Created from <em>ConditionalDeploy.register</em>, the end user should
    # never need to interact with it directly.
    class Unit
      VALID_CONDITIONS = [:any_match, :none_match, :if, :unless, :watchlist]

      attr_accessor :name, :message, :conditions, :block

      def initialize(name, opts, block)
        @name       = name
        @message    = opts.delete(:msg)
        @block      = block
        @conditions = {}
        @options    = {}

        opts.each do |k,v|
          if VALID_CONDITIONS.include?(k)
            @conditions[k] = v
          else
            @options[k] = v
          end
        end
      end

      def applies?(changed)
        @changed = changed
        return default == 'run' if ConditionalDeploy.in_default_mode?

        any_match_applies? && none_match_applies? && if_applies? && unless_applies?
      end

      def default
        (@options[:default] || :abort).to_s
      end

      protected

        def any_match_applies?
          any_files_match?(:any_match) && any_files_match?(:watchlist)
        end

        def none_match_applies?
          Array(conditions[:none_match]).all? do |watched|
            !@changed.any? { |path| path[watched] }
          end
        end

        def if_applies?
          return true if conditions[:if].nil?
          condition_true?(:if)
        end

        def unless_applies?
          return true if conditions[:unless].nil?
          !condition_true?(:unless)
        end

        def any_files_match?(key)
          return true unless conditions[key]
          Array(conditions[key]).any? do |watched|
            @changed.any? { |path| path[watched] }
          end
        end

        def condition_true?(label)
          c = conditions[label]
          case c.arity
          when 0 then c.call
          when 1 then c.call(@changed)
          else
            c.call(@changed, @git)
          end
        end

    end
  end
end
