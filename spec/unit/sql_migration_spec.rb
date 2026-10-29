# frozen_string_literal: true

require "tempfile"

RSpec.describe ROM::SQL::Migration::SQLParser do
  subject(:parser) { described_class.new }

  let(:db) { Sequel.sqlite }

  # Write `content` to a temporary `.sql` file and yield its path.
  def with_sql(content)
    Tempfile.create(["migration", ".sql"]) do |file|
      file.binmode
      file.write(content)
      file.flush
      yield file.path
    end
  end

  describe "default single-statement section" do
    it "sends the entire body as one statement and applies up" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE alpha (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:alpha)
      end
    end
  end

  describe "split=semicolon" do
    it "splits on `;` at end of line and runs each statement separately" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=semicolon
        CREATE TABLE beta (id INTEGER PRIMARY KEY);
        CREATE TABLE gamma (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:beta, :gamma)
      end
    end

    it "treats the trailing `;` on the final statement as optional" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=semicolon
        CREATE TABLE mu (id INTEGER PRIMARY KEY);
        CREATE TABLE nu (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:mu, :nu)
      end
    end
  end

  describe "split=line" do
    it "emits each non-empty line as a separate statement" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=line
        CREATE TABLE delta (id INTEGER PRIMARY KEY)
        CREATE TABLE epsilon (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:delta, :epsilon)
      end
    end
  end

  describe "transaction= pragma" do
    it "sets use_transactions=true for transaction=true" do
      with_sql(<<~SQL) do |path|
        -- @migrate transaction=true
        -- @migrate up
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect(parser.call(path).use_transactions).to be(true)
      end
    end

    it "sets use_transactions=false for transaction=false" do
      with_sql(<<~SQL) do |path|
        -- @migrate transaction=false
        -- @migrate up
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect(parser.call(path).use_transactions).to be(false)
      end
    end

    it "raises SQLParseError on an invalid value" do
      with_sql(<<~SQL) do |path|
        -- @migrate transaction=maybe
        -- @migrate up
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /transaction= must be "true" or "false"/
        )
      end
    end
  end

  describe "unknown settings" do
    it "silently ignores unknown pragma keys" do
      with_sql(<<~SQL) do |path|
        -- @migrate foo=bar
        -- @migrate up
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.not_to raise_error
      end
    end

    it "silently ignores unknown begin-directive keys" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin foo=bar
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.not_to raise_error
      end
    end
  end

  describe "directive-line correctness" do
    it "raises on stray text before a setting" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin foo bar=baz
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /Unrecognized content/
        )
      end
    end

    it "raises when a colon is used instead of equals in a setting" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split:semicolon
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /Unrecognized content/
        )
      end
    end

    it "raises when a setting is missing its value" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /Unrecognized content/
        )
      end
    end

    it "raises on an unknown split strategy" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=chunks
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /Unknown split strategy/
        )
      end
    end
  end

  describe "directive-line whitespace handling" do
    it "accepts multiple space characters between directive and setting" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin   split=semicolon
        CREATE TABLE zeta (id INTEGER PRIMARY KEY);
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:zeta)
      end
    end

    it "accepts a tab as separator" do
      source = "-- @migrate up\n-- @migrate begin\tsplit=line\nSELECT 1\n-- @migrate end\n"

      with_sql(source) do |path|
        expect { parser.call(path) }.not_to raise_error
      end
    end

    it "allows trailing whitespace after the last setting" do
      source = "-- @migrate up\n-- @migrate begin split=line   \nSELECT 1\n-- @migrate end\n"

      with_sql(source) do |path|
        expect { parser.call(path) }.not_to raise_error
      end
    end

    it "allows trailing whitespace after a bare directive" do
      source = "-- @migrate up   \n-- @migrate begin\nSELECT 1\n-- @migrate end\n"

      with_sql(source) do |path|
        expect { parser.call(path) }.not_to raise_error
      end
    end
  end

  describe "CRLF line endings" do
    let(:crlf_source) do
      "-- @migrate up\r\n" \
      "-- @migrate begin\r\n" \
      "CREATE TABLE eta (id INTEGER PRIMARY KEY)\r\n" \
      "-- @migrate end\r\n"
    end

    it "parses directive lines and applies cleanly" do
      with_sql(crlf_source) do |path|
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:eta)
      end
    end

    it "produces :line tokens without trailing \\r" do
      with_sql(crlf_source) do |path|
        tokens = File.open(path, "rb") { |f| parser.tokenize(f) }
        line_values = tokens.select { |t| t.type == :line }.map(&:value)

        expect(line_values).to all(satisfy { |v| !v.include?("\r") })
      end
    end

    it "emits no spurious :line tokens for blank CRLF lines" do
      source = "-- @migrate up\r\n" \
               "-- @migrate begin\r\n" \
               "\r\n" \
               "SELECT 1\r\n" \
               "-- @migrate end\r\n"

      with_sql(source) do |path|
        tokens = File.open(path, "rb") { |f| parser.tokenize(f) }
        line_values = tokens.select { |t| t.type == :line }.map(&:value)

        expect(line_values).to eq(["SELECT 1"])
      end
    end
  end

  describe "token position fidelity" do
    it "points :setting tokens at the start of the key, not the leading whitespace" do
      source = "-- @migrate up\n-- @migrate begin   split=semicolon\nSELECT 1\n-- @migrate end\n"

      with_sql(source) do |path|
        tokens = File.open(path) { |f| parser.tokenize(f) }
        setting = tokens.find { |t| t.type == :setting }

        # "-- @migrate begin" (17) + 3 spaces = col 20
        expect(setting).to have_attributes(value: "split=semicolon", pos: 20)
      end
    end
  end

  describe "error messages" do
    it "includes the file path on a directive-line parse error" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split:colon
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /#{Regexp.escape(path)}/
        )
      end
    end

    it "includes the file path on a transaction-value error" do
      with_sql(<<~SQL) do |path|
        -- @migrate transaction=maybe
        -- @migrate up
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /#{Regexp.escape(path)}/
        )
      end
    end

    it "includes the file path on a split-strategy error" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=chunks
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /#{Regexp.escape(path)}/
        )
      end
    end
  end

  describe "empty or content-only files" do
    it "raises a friendly error for an empty file" do
      with_sql("") do |path|
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /No @migrate directives found/
        )
      end
    end

    it "raises a friendly error for a file containing only SQL content" do
      with_sql(<<~SQL) do |path|
        -- this file has plain SQL comments
        SELECT 1;
        -- but no @migrate directives
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /No @migrate directives found/
        )
      end
    end
  end

  describe "trailing content after the final section" do
    it "raises when a second up section follows the first" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE x (id INTEGER PRIMARY KEY)
        -- @migrate end
        -- @migrate up
        -- @migrate begin
        CREATE TABLE y (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /Unexpected content after final section/
        )
      end
    end
  end

  describe "multiple sections per direction" do
    it "runs two consecutive up sections with different split settings" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE foo (id INTEGER PRIMARY KEY, val INTEGER)
        -- @migrate end
        -- @migrate begin split=semicolon
        INSERT INTO foo VALUES (1, 10);
        INSERT INTO foo VALUES (2, 20);
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)

        expect(db.tables).to include(:foo)
        expect(db[:foo].order(:id).all).to eq([
          {id: 1, val: 10},
          {id: 2, val: 20}
        ])
      end
    end

    it "supports multi-section up and multi-section down through a full lifecycle" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE foo (id INTEGER PRIMARY KEY)
        -- @migrate end
        -- @migrate begin
        CREATE INDEX foo_idx ON foo (id)
        -- @migrate end
        -- @migrate down
        -- @migrate begin
        DROP INDEX foo_idx
        -- @migrate end
        -- @migrate begin
        DROP TABLE foo
        -- @migrate end
      SQL
        migration = parser.call(path)

        migration.apply(db, :up)
        expect(db.tables).to include(:foo)
        expect(db.indexes(:foo)).to have_key(:foo_idx)

        migration.apply(db, :down)
        expect(db.tables).not_to include(:foo)
      end
    end

    it "silently skips an empty middle section" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE foo (id INTEGER PRIMARY KEY)
        -- @migrate end
        -- @migrate begin
        -- @migrate end
        -- @migrate begin
        CREATE INDEX foo_idx ON foo (id)
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)

        expect(db.tables).to include(:foo)
        expect(db.indexes(:foo)).to have_key(:foo_idx)
      end
    end

    it "raises when a direction has no begin..end section" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate down
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path) }.to raise_error(
          ROM::SQL::SQLParseError, /Expected begin, got down/
        )
      end
    end
  end

  describe "SQL comments inside section bodies" do
    it "tokenizes plain `--` comments as :line and passes them through verbatim" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        -- This is a real SQL comment, not a directive.
        CREATE TABLE notes (id INTEGER PRIMARY KEY);
        -- Another comment about the next statement.
        CREATE INDEX notes_id_idx ON notes (id);
        -- @migrate end
      SQL
        tokens = File.open(path) { |f| parser.tokenize(f) }
        line_values = tokens.select { |t| t.type == :line }.map(&:value)

        expect(line_values).to eq([
          "-- This is a real SQL comment, not a directive.",
          "CREATE TABLE notes (id INTEGER PRIMARY KEY);",
          "-- Another comment about the next statement.",
          "CREATE INDEX notes_id_idx ON notes (id);"
        ])

        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:notes)
      end
    end

    it "treats bare `@migrate` (no `--` prefix) as SQL content" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        SELECT '@migrate up' AS not_a_directive;
        -- @migrate end
      SQL
        tokens = File.open(path) { |f| parser.tokenize(f) }
        line_values = tokens.select { |t| t.type == :line }.map(&:value)

        expect(line_values).to eq(["SELECT '@migrate up' AS not_a_directive;"])
      end
    end
  end

  describe "applying a direction" do
    it "is a no-op when applying :down with no down section" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE up_only (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        migration = parser.call(path)
        expect { migration.apply(db, :down) }.not_to raise_error
      end
    end

    it "raises ArgumentError for an invalid direction" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        SELECT 1
        -- @migrate end
      SQL
        expect { parser.call(path).apply(db, :sideways) }.to raise_error(
          ArgumentError, /Invalid migration direction specified/
        )
      end
    end
  end

  describe "execution error backtraces" do
    it "annotates the backtrace with the failing line in a split=line section" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=line
        CREATE TABLE good (id INTEGER PRIMARY KEY)
        THIS IS NOT VALID SQL
        -- @migrate end
      SQL
        expect { parser.call(path).apply(db, :up) }.to raise_error(Sequel::DatabaseError) do |error|
          expect(error.backtrace.first).to eq("#{path}:4:in 'up'")
        end
      end
    end

    it "annotates the backtrace with the failing line in a split=semicolon section" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin split=semicolon
        CREATE TABLE good (id INTEGER PRIMARY KEY);
        BROKEN STATEMENT HERE;
        -- @migrate end
      SQL
        expect { parser.call(path).apply(db, :up) }.to raise_error(Sequel::DatabaseError) do |error|
          expect(error.backtrace.first).to eq("#{path}:4:in 'up'")
        end
      end
    end

    it "annotates the backtrace with the section's first line for a default (unsplit) body" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        BROKEN
        STATEMENT
        -- @migrate end
      SQL
        expect { parser.call(path).apply(db, :up) }.to raise_error(Sequel::DatabaseError) do |error|
          expect(error.backtrace.first).to eq("#{path}:3:in 'up'")
        end
      end
    end

    it "reports the down direction in the frame when a down statement fails" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE present (id INTEGER PRIMARY KEY)
        -- @migrate end
        -- @migrate down
        -- @migrate begin split=line
        DROP TABLE present
        DROP TABLE does_not_exist
        -- @migrate end
      SQL
        migration = parser.call(path)
        migration.apply(db, :up)

        expect { migration.apply(db, :down) }.to raise_error(Sequel::DatabaseError) do |error|
          expect(error.backtrace.first).to eq("#{path}:8:in 'down'")
        end
      end
    end
  end

  describe "env=true variable substitution" do
    around do |example|
      saved = ENV.to_h
      example.run
    ensure
      ENV.replace(saved)
    end

    it "substitutes ${NAME} from ENV in statement bodies" do
      ENV["MIG_TABLE"] = "widgets"

      with_sql(<<~SQL) do |path|
        -- @migrate env=true
        -- @migrate up
        -- @migrate begin
        CREATE TABLE ${MIG_TABLE} (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db.tables).to include(:widgets)
      end
    end

    it "leaves $$-quoted bodies and $1 params untouched" do
      ENV["MIG_VAL"] = "resolved"

      with_sql(<<~SQL) do |path|
        -- @migrate env=true
        -- @migrate up
        -- @migrate begin
        CREATE TABLE notes (body TEXT)
        -- @migrate end
        -- @migrate begin
        INSERT INTO notes (body) VALUES ('$1 $$ ${MIG_VAL}')
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db[:notes].get(:body)).to eq("$1 $$ resolved")
      end
    end

    it "passes ${NAME} through verbatim when no env pragma is set" do
      with_sql(<<~SQL) do |path|
        -- @migrate up
        -- @migrate begin
        CREATE TABLE notes (body TEXT)
        -- @migrate end
        -- @migrate begin
        INSERT INTO notes (body) VALUES ('${MIG_VAL}')
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db[:notes].get(:body)).to eq("${MIG_VAL}")
      end
    end

    it "passes ${NAME} through verbatim when env=false" do
      with_sql(<<~SQL) do |path|
        -- @migrate env=false
        -- @migrate up
        -- @migrate begin
        CREATE TABLE notes (body TEXT)
        -- @migrate end
        -- @migrate begin
        INSERT INTO notes (body) VALUES ('${MIG_VAL}')
        -- @migrate end
      SQL
        parser.call(path).apply(db, :up)
        expect(db[:notes].get(:body)).to eq("${MIG_VAL}")
      end
    end

    it "raises SQLEnvError naming the variable and source location for a missing var" do
      ENV.delete("MIG_MISSING")

      with_sql(<<~SQL) do |path|
        -- @migrate env=true
        -- @migrate up
        -- @migrate begin
        CREATE TABLE ${MIG_MISSING} (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        expect { parser.call(path).apply(db, :up) }.to raise_error(
          ROM::SQL::SQLEnvError, /\$\{MIG_MISSING\}.*#{Regexp.escape(path)}:4/
        )
      end
    end

    it "aborts before any side effects when a later statement has a missing var" do
      ENV.delete("MIG_MISSING")

      with_sql(<<~SQL) do |path|
        -- @migrate env=true
        -- @migrate up
        -- @migrate begin split=line
        CREATE TABLE created_first (id INTEGER PRIMARY KEY)
        CREATE TABLE ${MIG_MISSING} (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        expect { parser.call(path).apply(db, :up) }.to raise_error(ROM::SQL::SQLEnvError)
        expect(db.tables).not_to include(:created_first)
      end
    end

    it "honors transaction and env on a single pragma line" do
      ENV["MIG_TABLE"] = "combined"

      with_sql(<<~SQL) do |path|
        -- @migrate transaction=true env=true
        -- @migrate up
        -- @migrate begin
        CREATE TABLE ${MIG_TABLE} (id INTEGER PRIMARY KEY)
        -- @migrate end
      SQL
        migration = parser.call(path)
        expect(migration.use_transactions).to be(true)

        migration.apply(db, :up)
        expect(db.tables).to include(:combined)
      end
    end
  end
end
