# frozen_string_literal: true

require 'rom/sql/commands/error_wrapper'

module ROM
  module SQL
    module Commands
      # SQL create command
      #
      # @api public
      class Create < ROM::Commands::Create
        adapter :sql

        # Lets a relation carrying ON CONFLICT be used via `relation.command(:create)`
        restrictable true

        include ErrorWrapper

        use :associates
        use :schema

        after :finalize

        # Inserts provided tuples into the database table
        #
        # @api public
        def execute(tuples)
          insert_tuples = with_input_tuples(tuples) do |tuple|
            attributes = input[tuple]
            attributes.to_h
          end

          if insert_tuples.length > 1
            multi_insert(insert_tuples)
          else
            insert(insert_tuples)
          end
        end

        private

        # @api private
        def finalize(tuples, *)
          tuples.map { |t| relation.output_schema[t] }
        end

        # Executes insert statement and returns inserted tuples
        #
        # @api private
        def insert(tuples)
          pks = tuples.map { |tuple| relation.insert(tuple) }
          relation.dataset.where(relation.primary_key => pks).to_a
        end

        # Executes multi_insert statement and returns inserted tuples
        #
        # @api private
        def multi_insert(tuples)
          pks = relation.multi_insert(tuples, return: :primary_key)
          relation.dataset.where(relation.primary_key => pks).to_a
        end

        # Yields tuples for insertion or return an enumerator
        #
        # @api private
        def with_input_tuples(tuples, &)
          input_tuples = [tuples].flatten(1).map
          return input_tuples unless block_given?

          input_tuples.each(&)
        end
      end
    end
  end
end
