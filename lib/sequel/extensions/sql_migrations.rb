# frozen_string_literal: true

# Once loaded, all Sequel migrators in the process will accept `.sql` files
# alongside `.rb` files. `.sql` files are translated into
# `ROM::SQL::Migration::SQLMigration` instances by `ROM::SQL::Migration::SQLParser`,
# satisfying the same `apply(db, direction)` contract that Sequel's runner
# uses for all migrations.
#
# The extension uses `Module#prepend` to override the small set of methods
# in `Sequel::Migrator` and its subclasses that consult the hardcoded
# `MIGRATION_FILE_PATTERN`. Sequel's own `Migrator.migrator_class`
# integer-vs-timestamp selection logic is preserved.

Sequel.extension :migration

require "rom/sql/migration/sql_parser"

module ROM
  module SQL
    module Migration
      # @api private
      module SequelExtension
        # Replacement for `Sequel::Migrator::MIGRATION_FILE_PATTERN` that
        # additionally accepts `.sql` files.
        MIGRATION_FILE_PATTERN = /\A(\d+)_(.+)\.(rb|sql)\z/i.freeze

        # @api private
        module FileLoader
          private

          # @api private
          def load_migration_file(file)
            case File.extname(file).downcase
            when ".sql"
              sql_parser.call(file)
            else
              super
            end
          end

          def sql_parser
            @sql_parser ||= ROM::SQL::Migration::SQLParser.new
          end
        end

        # Prepended into `Sequel::Migrator`'s singleton class. Replaces the
        # `migrator_class` selector so the extension-aware pattern is used
        # when sniffing the directory for integer-vs-timestamp selection.
        #
        # @api private
        module MigratorClassSelector
          # @api private
          def migrator_class(directory)
            if equal?(Sequel::Migrator)
              raise Sequel::Migrator::Error, "Must supply a valid migration path" unless File.directory?(directory)

              Dir.new(directory).each do |file|
                next unless MIGRATION_FILE_PATTERN.match(file)
                return Sequel::TimestampMigrator if file.split("_", 2).first.to_i > 20000101
              end

              Sequel::IntegerMigrator
            else
              self
            end
          end
        end

        # Prepended into `Sequel::IntegerMigrator`. Re-implements
        # `get_migration_files` against the extension-aware pattern.
        #
        # @api private
        module IntegerMigratorFiles
          private

          # @api private
          def get_migration_files
            files = []
            Dir.new(directory).each do |file|
              next unless MIGRATION_FILE_PATTERN.match(file)

              version = migration_version_from_file(file)
              if version >= 20000101
                raise Sequel::Migrator::Error,
                      "Migration number too large, must use TimestampMigrator: #{file}"
              end
              if files[version]
                raise Sequel::Migrator::Error, "Duplicate migration version: #{version}"
              end

              files[version] = File.join(directory, file)
            end
            unless @allow_missing_migration_files
              1.upto(files.length - 1) do |i|
                raise Sequel::Migrator::Error, "Missing migration version: #{i}" unless files[i]
              end
            end
            files
          end
        end

        # Prepended into `Sequel::TimestampMigrator`. Re-implements
        # `get_migration_files` and `split_migration_filename` against the
        # extension-aware pattern.
        #
        # @api private
        module TimestampMigratorFiles
          private

          # @api private
          def get_migration_files
            files = []
            Dir.new(directory).each do |file|
              next unless MIGRATION_FILE_PATTERN.match(file)

              files << File.join(directory, file)
            end
            files.sort! do |a, b|
              a_ver, a_name = split_migration_filename(a)
              b_ver, b_name = split_migration_filename(b)
              x = a_ver <=> b_ver
              x = a_name <=> b_name if x.zero?
              x
            end
            files
          end

          # @api private
          def split_migration_filename(path)
            version, name, = MIGRATION_FILE_PATTERN
                               .match(File.basename(path))
                               .captures
            [version.to_i, name]
          end
        end
      end
    end
  end
end

Sequel::Migrator.prepend(ROM::SQL::Migration::SequelExtension::FileLoader)
Sequel::Migrator.singleton_class.prepend(ROM::SQL::Migration::SequelExtension::MigratorClassSelector)
Sequel::IntegerMigrator.prepend(ROM::SQL::Migration::SequelExtension::IntegerMigratorFiles)
Sequel::TimestampMigrator.prepend(ROM::SQL::Migration::SequelExtension::TimestampMigratorFiles)
