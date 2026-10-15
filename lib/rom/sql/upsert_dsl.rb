# frozen_string_literal: true

require 'rom/sql/restriction_dsl'

module ROM
  module SQL
    # DSL for the DO UPDATE part of INSERT ... ON CONFLICT statements
    #
    # Attributes refer to the existing row, `excluded` gives access to
    # the row proposed for insertion, like PostgreSQL's EXCLUDED pseudo-table.
    # Functions are resolved through the virtual row, as in the restriction DSL.
    #
    # @example
    #   users.on_conflict(:email).do_update {
    #     set(name: excluded[:name], updated_at: excluded[:updated_at])
    #       .where(updated_at < excluded[:updated_at])
    #   }
    #
    # @api public
    class UpsertDSL < RestrictionDSL
      # Immutable description of the update: assignments and an optional condition
      #
      # Every method returns a new instance, so the parts are chained
      #
      # @api public
      class Update
        # @!attribute [r] schema
        #   @return [SQL::Schema]
        attr_reader :schema

        # @!attribute [r] assignments
        #   @return [Hash] Column-value pairs for the SET clause
        attr_reader :assignments

        # @!attribute [r] condition
        #   @return [Object, nil] Condition for the WHERE clause
        attr_reader :condition

        # @api private
        def initialize(schema, assignments = EMPTY_HASH, condition = nil)
          @schema = schema
          @assignments = assignments
          @condition = condition
          freeze
        end

        # Add assignments, later ones take precedence
        #
        # @param [Hash] pairs Column-value pairs
        #
        # @return [Update]
        #
        # @api public
        def set(**pairs)
          self.class.new(schema, assignments.merge(pairs), condition)
        end

        # Restrict the update to rows matching the condition
        #
        # @param [Hash, Object] condition
        #
        # @return [Update]
        #
        # @api public
        def where(condition)
          self.class.new(schema, assignments, qualify(condition))
        end

        private

        # Bare column names in DO UPDATE ... WHERE are ambiguous
        # between the table and EXCLUDED
        #
        # @api private
        def qualify(condition)
          return condition unless condition.is_a?(Hash)

          condition.to_h { |key, value|
            [key.is_a?(Symbol) && schema.key?(key) ? schema[key].qualified : key, value]
          }
        end
      end

      # Row proposed for insertion
      #
      # @return [SQL::Schema] Schema with attributes qualified with `excluded`
      #
      # @api public
      def excluded
        @excluded ||= schema.qualified(:excluded)
      end

      # Start the update with assignments
      #
      # @see Update#set
      #
      # @api public
      def set(**pairs)
        Update.new(schema).set(**pairs)
      end

      # Start the update with a condition
      #
      # @see Update#where
      #
      # @api public
      def where(condition)
        Update.new(schema).where(condition)
      end

      # @return [Array(Hash, Object)] Assignments and condition
      #
      # @api private
      def call(&)
        result = super

        case result
        when Update then [result.assignments, result.condition]
        when ::Hash then [result, nil]
        else
          ::Kernel.raise ::ArgumentError, "expected set(...) or a hash, got #{result.inspect}"
        end
      end
    end
  end
end
