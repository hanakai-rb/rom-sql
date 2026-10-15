# frozen_string_literal: true

require 'rom/sql/types'
require 'rom/sql/schema'
require 'rom/sql/attribute'
require 'rom/sql/wrap'
require 'rom/sql/transaction'

require 'rom/sql/relation/reading'
require 'rom/sql/relation/writing'
require 'rom/sql/relation/conflicts'

module ROM
  module SQL
    # Sequel-specific relation extensions
    #
    # @api public
    class Relation < ROM::Relation
      adapter :sql

      include SQL
      include Writing
      include Conflicts
      include Reading

      extend Notifications::Listener

      schema_class SQL::Schema
      schema_attr_class SQL::Attribute
      schema_inferrer ROM::SQL::Schema::Inferrer.new.freeze
      schema_dsl SQL::Schema::DSL
      wrap_class SQL::Wrap

      subscribe('configuration.relations.schema.set', adapter: :sql) do |event|
        schema = event[:schema]
        relation = event[:relation]

        relation.dataset do
          table = opts[:from].first

          if db.table_exists?(table)
            select(*schema.qualified_projection).order(
              *schema.project(*schema.primary_key_names).qualified
            )
          else
            self
          end
        end
      end

      subscribe('configuration.relations.dataset.allocated', adapter: :sql) do |event|
        event[:relation].define_default_views!
      end

      # @api private
      #
      # rubocop:disable Metrics/MethodLength
      def self.define_default_views!
        undef_method :by_pk if method_defined?(:by_pk)

        if schema.primary_key.size > 1
          pks = schema.primary_key
          # @!method by_pk(val1, val2)
          #   Return a relation restricted by its composite primary key
          #
          #   @param [Array] args A list with composite pk values
          #
          #   @return [SQL::Relation]
          #
          #   @api public
          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def by_pk(#{pks.map(&:name).join(", ")})                     # def by_pk(val1, val2)
              s = schema.canonical                                       #   s = schema.canonical
              where(                                                     #   where(
                #{pks.map { "s[:#{_1.name}] => #{_1.name}" }.join(", ")} #     s[:val1] => val1, s[:val2] => val2
              )                                                          #   )
            end                                                          # end
          RUBY
        else
          # @!method by_pk(pk)
          #   Return a relation restricted by its primary key
          #
          #   @param [Object] pk The primary key value
          #
          #   @return [SQL::Relation]
          #
          #   @api public
          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def by_pk(pk)                                    # def by_pk(pk)
              s = schema.canonical                           #   s = schema.canonical
              if primary_key.nil?                            #   if primary_key.nil?
                raise MissingPrimaryKeyError.new(            #     raise MissingPrimaryKeyError.new(
                  "Missing primary key for :\#{schema.name}" #       "Missing primary key for :#{schema.name}"
                )                                            #     )
              end                                            #   end
              where(s[s.primary_key_name].qualified => pk)   #   where(s[s.primary_key_name].qualified => pk)
            end                                              # end
          RUBY
        end
      end
      # rubocop:enable Metrics/MethodLength

      # @api private
      def self.associations
        schema.associations
      end

      # @api private
      def self.primary_key_columns(db, table)
        names = db.respond_to?(:primary_key) ? Array(db.primary_key(table)) : [:id]
        names.map { |col| :"#{table}__#{col}" }
      end

      option :primary_key, default: -> { schema.primary_key_name }

      # Return relation that will load associated tuples of this relation
      #
      # This method is useful for defining custom relation views for relation
      # composition when you want to enhance default association query
      #
      # @example
      #   assoc(:tasks).where(tasks[:title] => "Task One")
      #
      # @param [Symbol] name The association name
      #
      # @return [Relation]
      #
      # @api public
      def assoc(name)
        associations[name].()
      end

      # Open a database transaction
      #
      # @param [Hash] opts
      # @option opts [Boolean] :auto_savepoint
      #         Automatically use a savepoint for Database#transaction
      #         calls inside this transaction block.
      # @option opts [Symbol] :isolation
      #         The transaction isolation level to use for this transaction,
      #         should be :uncommitted, :committed, :repeatable, or :serializable,
      #         used if given and the database/adapter supports customizable
      #         transaction isolation levels.
      # @option opts [Integer] :num_retries
      #         The number of times to retry if the :retry_on option is used.
      #         The default is 5 times. Can be set to nil to retry indefinitely,
      #         but that is not recommended.
      # @option opts [Proc] :before_retry
      #         Proc to execute before rertrying if the :retry_on option is used.
      #         Called with two arguments: the number of retry attempts (counting the
      #         current one) and the error the last attempt failed with.
      # @option opts [String] :prepare
      #         A string to use as the transaction identifier for a prepared transaction
      #         (two-phase commit), if the database/adapter supports prepared transactions.
      # @option opts [Class] :retry_on
      #         An exception class or array of exception classes for which to automatically
      #         retry the transaction. Can only be set if not inside an existing transaction.
      #         Note that this should not be used unless the entire transaction block is
      #         idempotent, as otherwise it can cause non-idempotent behavior to execute
      #         multiple times.
      # @option opts [Symbol] :rollback
      #         Can be set to :reraise to reraise any Sequel::Rollback
      #         exceptions raised, or :always to always rollback even if no
      #         exceptions occur (useful for testing).
      # @option opts [Symbol] :server
      #         The server to use for the transaction. Set to :default, :read_only,
      #         or whatever symbol you used in the connect string when naming
      #         your servers.
      # @option opts [Boolean] :savepoint
      #         Whether to create a new savepoint for this transaction, only
      #         respected if the database/adapter supports savepoints. By default
      #         Sequel will reuse an existing transaction, so if you want to use a
      #         savepoint you must use this option. If the surrounding transaction
      #         uses :auto_savepoint, you can set this to false to not use a savepoint.
      #         If the value given for this option is :only, it will only create a
      #         savepoint if it is inside a transacation.
      # @option opts [Boolean] :deferrable
      #         If present, set to DEFERRABLE if true or NOT DEFERRABLE if false.
      # @option opts [Boolean] :read_only
      #         **PG only** If present, set to READ ONLY if true or READ WRITE if false.
      # @option opts [Symbol] :synchronous
      #         **PG only** If non-nil, set synchronous_commit appropriately.
      #         Valid values true, :on, false, :off, :local, and :remote_write.
      #
      # @yield [t] Transaction
      #
      # @return [Mixed]
      #
      # @api public
      def transaction(opts = EMPTY_HASH, &)
        Transaction.new(dataset.db).run(opts, &)
      end

      # Return raw column names
      #
      # @return [Array<Symbol>]
      #
      # @api private
      def columns
        @columns ||= dataset.columns
      end
    end
  end
end
