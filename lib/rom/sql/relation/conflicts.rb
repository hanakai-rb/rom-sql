# frozen_string_literal: true

require 'rom/sql/upsert_dsl'

module ROM
  module SQL
    class Relation < ROM::Relation
      # Building INSERT ... ON CONFLICT statements
      #
      # @api public
      module Conflicts
        # Handle conflicts with unique constraints on insert
        #
        # Returns a relation carrying an ON CONFLICT clause, so any insert
        # through it becomes an upsert: `insert`, `multi_insert`, `import`,
        # `command(:create)` and changesets. Conflicts are ignored unless
        # `do_update` is chained.
        #
        # @example ignore conflicting rows
        #   users.on_conflict(:email).insert(name: 'Jane', email: 'jane@doe.org')
        #
        # @example infer a partial unique index
        #   users.on_conflict(:email) { active.is(true) }.insert(...)
        #
        # @example use a named constraint
        #   users.on_conflict(constraint: :users_email_key).insert(...)
        #
        # @example pass the index predicate as a value
        #   def create(email:)
        #     users.on_conflict(:email, where: users[:email].not(nil)).insert(email: email)
        #   end
        #
        # @param [Array<Symbol, SQL::Attribute>] target Columns of the unique index
        # @param [Symbol] constraint Name of the constraint, takes precedence over target
        # @param [Hash, SQL::Attribute, Sequel::SQL::Expression] where Index predicate,
        #   for when a local variable in the block would shadow a column of the same name
        #
        # @yield Index predicate built with the restriction DSL
        #
        # @raise [ArgumentError] when both `where` and a block are given
        #
        # @return [Relation]
        #
        # @api public
        def on_conflict(*target, constraint: nil, where: nil, &block)
          if where && block
            raise ArgumentError, 'pass the index predicate either as where: or as a block, not both'
          end

          predicate = block ? schema.canonical.restriction(&block) : where
          opts = conflict_options.except(:target, :constraint, :conflict_where)

          new(insert_conflict(opts.merge(conflict_target(target, constraint, predicate))))
        end

        # Update the existing row on conflict
        #
        # Without arguments every column except the primary key and the
        # conflict target is set from the excluded row, i.e. the one proposed
        # for insertion. Listed columns restrict that, pairs set arbitrary
        # values, and the block gives access to the upsert DSL.
        #
        # Subsequent calls add to the update: their assignments are merged
        # over the previous ones, later ones taking precedence, and their
        # conditions are joined with AND.
        #
        # @example set columns from the excluded row
        #   users.on_conflict(:email).do_update(:name, :updated_at).insert(...)
        #
        # @example set values and expressions
        #   users.on_conflict(:email).do_update(removed_at: nil).insert(...)
        #
        # @example use the DSL
        #   users.on_conflict(:email).do_update {
        #     set(last_seen_at: greatest(last_seen_at, excluded[:last_seen_at]))
        #       .where(updated_at < excluded[:updated_at])
        #   }.multi_insert(tuples)
        #
        # @example build the update in steps
        #   users.on_conflict(:email).do_update(:name).do_update(updated_at: now)
        #
        # @param [Array<Symbol>] columns Columns to set from the excluded row
        # @param [Hash] pairs Column-value pairs
        #
        # @yield Block evaluated with the upsert DSL, returns `set(...)` or a hash
        #
        # @return [Relation]
        #
        # @see UpsertDSL
        #
        # @api public
        def do_update(*columns, **pairs, &)
          assignments, condition = conflict_update(columns, pairs, &)
          merged = conflict_options.fetch(:update, EMPTY_HASH).merge(assignments)
          previous_condition = conflict_options[:update_where]

          opts = conflict_options.merge(
            update: merged.empty? ? default_conflict_assignments : merged,
            update_where: [previous_condition, condition].compact.reduce { |a, b| Sequel.&(a, b) }
          )

          new(insert_conflict(opts.compact))
        end

        # Ignore the conflicting row
        #
        # This is the default of `on_conflict`, the method exists to revert
        # a previous `do_update`
        #
        # @return [Relation]
        #
        # @api public
        def do_nothing
          new(insert_conflict(conflict_options.except(:update, :update_where)))
        end

        # Row proposed for insertion in ON CONFLICT DO UPDATE
        #
        # @example
        #   users.on_conflict(:email).do_update(name: users.excluded[:name])
        #
        # @return [SQL::Schema] Schema with attributes qualified with `excluded`
        #
        # @api public
        def excluded
          schema.qualified(:excluded)
        end

        private

        # @api private
        def insert_conflict(opts)
          unless dataset.respond_to?(:insert_conflict)
            raise UnsupportedFeatureError,
                  "ON CONFLICT is not supported by #{dataset.db.database_type}"
          end

          dataset.insert_conflict(opts)
        end

        # Target part of the ON CONFLICT clause
        #
        # @api private
        def conflict_target(target, constraint, predicate)
          {
            constraint: constraint,
            target: (target.map { |t| t.is_a?(Attribute) ? t.name : t } unless target.empty?),
            conflict_where: predicate
          }.compact
        end

        # Options of the ON CONFLICT clause set on the dataset
        #
        # @api private
        def conflict_options
          opts = dataset.opts[:insert_conflict] || dataset.opts[:insert_on_conflict]
          opts.is_a?(Hash) ? opts : EMPTY_HASH
        end

        # Assignments and condition of the DO UPDATE clause
        #
        # @return [Array(Hash, Object)]
        #
        # @api private
        def conflict_update(columns, pairs, &block)
          assignments = columns.to_h { |column| [column, excluded[column]] }.merge(pairs)
          condition = nil

          if block
            dsl_assignments, condition = UpsertDSL.new(schema).call(&block)
            assignments = assignments.merge(dsl_assignments)
          end

          [assignments.to_h { |k, v| [k.is_a?(Attribute) ? k.name : k, v] }, condition]
        end

        # Every column except the primary key and the conflict target
        #
        # @api private
        def default_conflict_assignments
          keys = schema.primary_key.map(&:name) + Array(conflict_options[:target])
          (schema.map(&:name) - keys).to_h { |name| [name, excluded[name]] }
        end
      end
    end
  end
end
