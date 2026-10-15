# frozen_string_literal: true

module ROM
  module SQL
    class Relation < ROM::Relation
      module Writing
        # Return columns of the rows written
        #
        # Inserts, updates and deletes through the returned relation answer
        # the listed columns of every row they wrote, as an array of hashes,
        # instead of a primary key or a count. Without arguments every column
        # is returned. Reading from the relation is unaffected.
        #
        # @example return the ids of the rows an upsert actually wrote
        #   users.on_conflict(:email).returning(:id).multi_insert(tuples)
        #   # => [{ id: 1 }, { id: 3 }]
        #
        # @param [Array<Symbol, SQL::Attribute>] columns
        #
        # @raise [UnsupportedFeatureError] when the database has no RETURNING
        #
        # @return [Relation]
        #
        # @api public
        def returning(*columns)
          unless dataset.supports_returning?(:insert)
            raise UnsupportedFeatureError,
                  "RETURNING is not supported by #{dataset.db.database_type}"
          end

          new(dataset.returning(*columns.map { |c| c.is_a?(Attribute) ? c.name : c }))
        end

        # Add upsert option (only PostgreSQL >= 9.5)
        # Uses internal Sequel implementation
        # Default - ON CONFLICT DO NOTHING
        # more options: http://sequel.jeremyevans.net/rdoc-adapters/classes/Sequel/Postgres/DatasetMethods.html#method-i-insert_conflict
        #
        # @example
        #   users.upsert({ name: 'Jane', email: 'jane@foo.com' },
        #                { target: :email, update: { name: :excluded__name } })
        #
        # @return [Integer] Number of affected rows
        #
        # @api public
        def upsert(*args, &)
          if args.size > 1 && args[-1].is_a?(Hash)
            *values, opts = args
          else
            values = args
            opts = EMPTY_HASH
          end

          dataset.insert_conflict(opts).insert(*values, &)
        end

        # Insert tuple into relation
        #
        # @example
        #   users.insert(name: 'Jane')
        #
        # @param [Hash] args
        #
        # @return [Hash] Inserted tuple
        #
        # @api public
        def insert(...)
          dataset.insert(...)
        end

        # Multi insert tuples into relation
        #
        # @example
        #   users.multi_insert([{name: 'Jane'}, {name: 'Jack'}])
        #
        # @param [Array<Hash>] tuples
        # @param [Hash] options Passed on to Sequel's `multi_insert`
        #
        # @return [Array<String>, Array<Hash>] A list of executed SQL statements,
        #   or the returned rows when the relation carries `returning`
        #
        # @api public
        def multi_insert(tuples, options = EMPTY_HASH)
          if dataset.opts.key?(:returning) && options.empty?
            returning_multi_insert(tuples)
          else
            dataset.multi_insert(tuples, options)
          end
        end

        # Update tuples in the relation
        #
        # @example
        #   users.update(name: 'Jane')
        #   users.where(name: 'Jane').update(name: 'Jane Doe')
        #
        # @return [Integer] Number of updated rows
        #
        # @api public
        def update(...)
          dataset.update(...)
        end

        # Delete tuples from the relation
        #
        # @example
        #   users.delete # deletes all
        #   users.where(name: 'Jane').delete # delete tuples
        #                                      from restricted relation
        #
        # @return [Integer] Number of deleted tuples
        #
        # @api public
        def delete(...)
          dataset.delete(...)
        end

        # Insert tuples from other relation
        #
        # NOTE: The method implicitly uses a transaction
        #
        # @example
        #   users.import(new_users)
        #
        # @overload import(other_sql_relation, options)
        #   If both relations uses the same gateway
        #   the INSERT ... SELECT statement will
        #   be used for importing the data
        #
        #   @param [SQL::Relation] other_sql_relation
        #
        #   @option [Integer] :slice
        #     Split loading into batches of provided size,
        #     every batch will be processed in a separate
        #     transaction block
        #
        # @overload import(other, options)
        #   Import data from another relation. The source
        #   relation will be materialized before loading
        #
        #   @param [Relation] other
        #
        #   @option [Integer] :slice
        #
        # @return [Integer] Number of imported tuples
        #
        # @api public
        def import(other, options = EMPTY_HASH)
          columns = other.schema.map { |a| a.alias || a.name }

          if other.gateway.eql?(gateway)
            dataset.import(columns, other.dataset, options)
          else
            keys = columns.map(&:to_sym)
            dataset.import(
              columns,
              other.to_a.map { |record|
                record.to_h.values_at(*keys)
              },
              options
            )
          end
        end

        private

        # Sequel's multi_insert answers bare values for a single returned
        # column on PostgreSQL and drops RETURNING rows altogether on SQLite,
        # so the statements are run here and every row comes back as a hash
        #
        # @api private
        def returning_multi_insert(tuples)
          if tuples.empty?
            EMPTY_ARRAY
          else
            columns = tuples.first.keys
            values = tuples.map { |tuple| tuple.values_at(*columns) }

            dataset.multi_insert_sql(columns, values).flat_map { |sql| dataset.with_sql(sql).to_a }
          end
        end
      end
    end
  end
end
