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
        watchlist_applies? && negative_watchlist_applies? && if_applies? && unless_applies?
      end  

      protected
  
        def watchlist_applies?
          return true if conditions[:watchlist].blank?
          matching_files_changed?(conditions[:watchlist])
        end
        
        def negative_watchlist_applies?
          return true if conditions[:negative_watchlist].blank?
          !matching_files_changed?(conditions[:negative_watchlist])
        end
    
        def if_applies?
          return true if conditions[:if].nil? 
          condition_true?(:if)
        end
    
        def unless_applies?
          return true if conditions[:unless].nil?
          !condition_true?(:unless)
        end
        
        
        
        def matching_files_changed?(watchlist)
          Array(watchlist).any? do |watched| 
            @changed.any? do |path| 
              path[watched]
            end
          end
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