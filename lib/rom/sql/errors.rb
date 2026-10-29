# frozen_string_literal: true

require 'sequel/deprecated'
require 'sequel/exceptions'

require 'rom/sql/error'

module ROM
  module SQL
    MissingConfigurationError = Class.new(StandardError)
    NoAssociationError        = Class.new(StandardError)
    DatabaseError             = Class.new(Error)
    ConstraintError           = Class.new(Error)
    NotNullConstraintError    = Class.new(ConstraintError)
    UniqueConstraintError     = Class.new(ConstraintError)
    ForeignKeyConstraintError = Class.new(ConstraintError)
    CheckConstraintError      = Class.new(ConstraintError)
    UnknownDBTypeError        = Class.new(StandardError)
    MissingPrimaryKeyError    = Class.new(StandardError)
    MigrationError            = Class.new(StandardError)
    UnsupportedConversion     = Class.new(MigrationError)
    SQLParseError             = Class.new(MigrationError)
    SQLEnvError               = Class.new(MigrationError)

    ERROR_MAP = {
      Sequel::DatabaseError => DatabaseError,
      Sequel::ConstraintViolation => ConstraintError,
      Sequel::NotNullConstraintViolation => NotNullConstraintError,
      Sequel::UniqueConstraintViolation => UniqueConstraintError,
      Sequel::ForeignKeyConstraintViolation => ForeignKeyConstraintError,
      Sequel::CheckConstraintViolation => CheckConstraintError
    }.freeze
  end
end
