module Capistrano
  module Conditional
    class Unit
      attr_accessor :name, :message, :conditions, :block

      def initialize(name, opts, block)
        @name = name
        @message = opts.delete(:msg)
        @block = block
        @conditions = {}
        opts.each do |k,v|
          @conditions[k] = v
        end
      end
  
      def applies?(changed)
        @changed = changed
        any_match_applies? && none_match_applies? && if_applies? && unless_applies?
      end  

      protected
  
        def any_match_applies?
          Array(conditions[:any_match]).any? do |watched| 
            @changed.any? { |path| path[watched] }
          end
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
        
        
        def condition_true?(label)
          c = conditions[label]
          case c.arity
          when 0 then c.call
          when 1 then c.call(@changed)
          else 2 
            c.call(@changed, @git)
          end
        end 
        
    end 
  end
end