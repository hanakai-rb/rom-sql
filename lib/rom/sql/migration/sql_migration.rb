# frozen_string_literal: true

require "dry/struct"

require "rom/sql/types"

module ROM
  module SQL
    module Migration
      # A single executable statement extracted from a `.sql` migration
      # section, paired with the source line where it begins. The line is
      # used to annotate backtraces when execution fails.
      #
      # @api private
      Statement = Data.define(:sql, :line)

      # A migration translated from a `.sql` file by `SQLParser`.
      #
      # @api private
      class SQLMigration < Dry::Struct
        Filename   = Types::Coercible::String
        Settings   = Types::Strict::Hash.default { {} }
        Direction  = Types::Strict::Symbol.enum(:up, :down)
        Statements = Types::Array.of(Types.Instance(Statement))

        # Matches `${NAME}` substitution references in statement bodies when the
        # `env=true` pragma is set. Only the braced form is recognized, leaving
        # `$$`-quoted bodies and `$1` positional params untouched.
        SUBSTITUTION = /\$\{(?<name>[A-Za-z_]\w*)\}/

        attribute :filename, Filename
        attribute :settings, Settings

        attribute :up, Statements
        attribute? :down, Statements

        # Return a copy with additional settings merged in.
        #
        # @api private
        def with(**settings)
          new(settings: self.settings.merge(settings))
        end

        # Whether to run inside a transaction.
        #
        # @return [true, false, nil] nil leaves the choice to the database default
        #
        # @api private
        def use_transactions
          settings[:transaction]
        end

        # Execute the statements for the given direction against the database.
        #
        # @param db [Sequel::Database]
        # @param direction [:up, :down]
        #
        # @api private
        def apply(db, direction)
          unless Direction.valid?(direction)
            raise ArgumentError, "Invalid migration direction specified (#{direction.inspect})"
          end

          statements = public_send(direction) or return

          # Resolve every statement before running any, so a missing environment
          # variable aborts before producing side effects.
          finalized = statements.map { |statement| apply_env(statement) }

          finalized.each do |statement|
            db.run(statement.sql)
          rescue Sequel::DatabaseError => e
            raise annotate(e, statement, direction)
          end
        end

        private

        # Return the statement with `${NAME}` environment-variable substitution
        # applied to its SQL when the `env` pragma is set. Raises `SQLEnvError`
        # for a referenced variable that is not present in `ENV`.
        #
        # @api private
        def apply_env(statement)
          return statement unless settings[:env]

          sql = statement.sql.gsub(SUBSTITUTION) do
            name = Regexp.last_match[:name]
            ENV.fetch(name) do
              raise SQLEnvError,
                    "Undefined environment variable ${#{name}} in #{filename}:#{statement.line}"
            end
          end

          statement.with(sql:)
        end

        # Prepend a synthetic frame pointing at the failing statement's source
        # location, so the migration file appears at the top of the backtrace.
        #
        # @api private
        def annotate(error, statement, direction)
          frame = "#{filename}:#{statement.line}:in '#{direction}'"
          trace = error.backtrace || []
          error.set_backtrace([frame, *trace])
          error
        end
      end
    end
  end
end
