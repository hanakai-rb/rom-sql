# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

- Support plain SQL migrations. Write a migration as a `.sql` file in your migrations directory, and use `-- @migrate` comment directives to mark its up and down sections. (@alassek in #440)

    ```sql
    -- @migrate up
    -- @migrate begin split=semicolon
    CREATE TABLE users (id INTEGER PRIMARY KEY);
    CREATE INDEX users_id_idx ON users (id);
    -- @migrate end

    -- @migrate down
    -- @migrate begin
    DROP TABLE users
    -- @migrate end
    ```

    Each direction can have one or more `begin`/`end` sections, which run in order. Use `split=` on a `begin` line to run its body as one statement (the default), split it on semicolons (`split=semicolon`), or split it by line (`split=line`). The down section is optional.

### Changed

- Require Ruby 3.2 or later. (@flash-gordon)

### Deprecated

### Removed

### Fixed

- Apply read types only once to tuples returned from Create commands. Before, read types were applied twice on all databases except PostgreSQL, which caused errors for read types that could not be applied twice. (@katafrakt in #432)

### Security

[Unreleased]: https://github.com/hanakai-rb/rom-sql/compare/v3.7.0...main

## [3.7.0] - 2025-01-08

### Changed

- Minimum Ruby version is now 3.1 (@flash-gordon)

[3.7.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.6.5...v3.7.0

## [3.6.5] - 2024-12-25

### Fixed

- Fix syntax error under Ruby 3.4 (@flash-gordon)

[3.6.5]: https://github.com/hanakai-rb/rom-sql/compare/v3.6.4...v3.6.5

## [3.6.4] - 2024-07-01

### Fixed

- Excessive logging when same gateway is shared between multiple containers (@flash-gordon)
- Warning about using color option from active-support log subscriber (@flash-gordon + @bendangelo)

[3.6.4]: https://github.com/hanakai-rb/rom-sql/compare/v3.6.3...v3.6.4

## [3.6.3] - 2024-05-06

### Fixed

- Fix using `.filter` with a block for aggregate functions (@flash-gordon)

[3.6.3]: https://github.com/hanakai-rb/rom-sql/compare/v3.6.2...v3.6.3

## [3.6.2] - 2024-01-09

### Fixed

- Fix Hash.new warning in Ruby 3.3 (@flash-gordon)

[3.6.2]: https://github.com/hanakai-rb/rom-sql/compare/v3.6.1...v3.6.2

## [3.6.1] - 2022-11-22

### Fixed

- Mapping of cidr types in PostgreSQL to IPAddr values (@flash-gordon)

[3.6.1]: https://github.com/hanakai-rb/rom-sql/compare/v3.6.0...v3.6.1

## [3.6.0] - 2022-11-11

### Added

- Add ROM::SQL::RakeSupport.migration_options for passing custom options to migrator (@wuarmin)

### Changed

- Upgraded to the latest versions of dry-rb dependencies, compatible with rom 5.3 (@flash-gordon)

[3.6.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.5.0...v3.6.0

## [3.5.0] - 2021-03-26

### Added

- Support for using partial indixes in PG upsert commands (issue #394 fixed via #395) (@smaximov)

### Fixed

- Restored the fix for #390 that was lost by an accident in 3.3.3 and 3.4.0 (@solnic)

[3.5.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.4.0...v3.5.0

## [3.4.0] - 2021-03-19

### Added

- `Relation#unordered` (@radar)

[3.4.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.3.3...v3.4.0

## [3.3.3] - 2021-03-05

### Added

- Support for streaming composite relations (@ianks)

[3.3.3]: https://github.com/hanakai-rb/rom-sql/compare/v3.3.2...v3.3.3

## [3.3.2] - 2021-01-06

### Fixed

- Function qualification methods no longer lose options (issue #390 fixed via #391) (@solnic)

[3.3.2]: https://github.com/hanakai-rb/rom-sql/compare/v3.3.1...v3.3.2

## [3.3.1] - 2020-12-29

### Fixed

- `:pg_streaming` plugin no longer crashes when there's no sequel_pg and now you need to require the plugin explicitly (@solnic)

[3.3.1]: https://github.com/hanakai-rb/rom-sql/compare/v3.3.0...v3.3.1

## [3.3.0] - 2020-12-28

### Added

- `Relation#full_text_search` that provides an API for [PostgreSQL's Full Text Search](https://www.postgresql.org/docs/9.5/textsearch.html) (@ianks)

```ruby
# Don't forget to activate the plugin
conf.plugin(:sql, relations: :pg_full_text_search)

posts.full_text_search([:title], 'tutorials', language: 'english')
# => [{ title: 'A Tutorial about SQL', ... }]
```
- Support for `:pg_streaming` extension (@ianks)

### Fixed

- `Relation#join` no longer crashes when aliased relation is used with a block (issue #369) (@abrthel)
- Attributes aliases are properly handled when constructing queries with SQL functions (issue #370 fixed via #373) (@abrthel)

[3.3.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.2.0...v3.3.0

## [3.2.0] - 2020-01-11

### Fixed

- Keyword warnings on Ruby 2.7 (@flash-gordon)

[3.2.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.1.0...v3.2.0

## [3.1.0] - 2019-12-16

### Added

- `.nullify` that turns the result set of any relation into an empty set. Analogue of `ActiveRecord#none` (@ianks + @flash-gordon)

  ```ruby
  # Don't forget to activate the plugin
  conf.relation(:users) do
    use :nullify
  end

  users.nullify.count # => will always be 0
  users.nullify.to_a # => will always be empty ([])
  ```

### Fixed

- Make `Relation#wrap` respect association views (@ianks)
- Primitive JSON-compatible values such as Integer and String are automatically coerced to correct JSONB values and back if you're using a recent Sequel version (>= 5.2.0) (@flash-gordon)
- Properly qualify relations when in `Relation#union` (@ianks)
- `Relation#query` no longer removes order in the relation (@DNNX)

[3.1.0]: https://github.com/hanakai-rb/rom-sql/compare/v3.0.1...v3.1.0

## [3.0.1] - 2019-05-05

### Fixed

- Using joins with a relation object as the target and a block-based conditions produces correct query now (issue #331) (solnic)

[3.0.1]: https://github.com/hanakai-rb/rom-sql/compare/v3.0.0...v3.0.1

## [3.0.0] - 2019-04-24

### Added

- Join DSL so that you can use arbitrary conditions when joining relations (flash-gordon)
  ```ruby
  users.join(tasks) { |users:, tasks:|
    tasks[:user_id].is(users[:id]) & users[:name].is('John')
  }
  ```
  You also can use table aliases, however the setup is a bit hairy:
  ```ruby
  # self-join "users" with itself using "authors" as an alias
  authors = users.as(:authors).qualified(:authors)
  result = users.join(authors) { |users: |
    users[:id].is(authors[:id])
  }.select(:name)
  ```
- Support for `CASE` expression (wmaciejak + flash-gordon)

  ```ruby
  # matching expression result
  users.select_append { id.case(1 => string('one'), else: string('something else')).as(:one_or_else) }

  # searching for `true` result
  users.select_append { string::case(id.is(1) => 'one', else: 'else').as(:one_or_else) }
  ```
- Relations can be accessed in DSLs with keyword arguments (flash-gordon)
  ```ruby
  users.join(posts).select_append { |posts: | posts[:title] }
  ```
- Support for `.exists` in the projection DSL (flash-gordon)
  ```ruby
  users.select_append { |posts: |
    exists(posts.where(posts[:user_id] => id)).as(:has_posts)
  }
  ```
- `Relation#unfiltered` returns an unrestricted relation (removes restrictions from `WHERE` and `HAVING`) (flash-gordon)
- Support for `WITHIN GROUP` in the function DSL has been enhanced with block syntax (flash-gordon)
  ```ruby
  # previously available version
  households.project { float::percentile_cont(0.5).within_group(income).as(:percentile) }
  # using the new syntax
  households.project { float::percentile_cont(0.5).within_group { income }.as(:percentile) }
  ```
- Support for migrator options ie `ROM::Configuration.new(:sql, migrator: { path: "my_migrations" })` (rawburt)
- `Relation#pluck` works with multiple args too (timriley)

### Changed

- [BREAKING] Updated to work with `dry-types 1.0.0` (flash-gordon)
- [BREAKING] `Types::Int` is now `Types::Integer` (GustavoCaso)

### Fixed

- Using `Relation#inner_join` with has-many-through produces correct query (issue #279) (doriantaylor + solnic)
- Aliased attributes are handled correctly in `Relation#where` (waiting-for-dev)

[3.0.0]: https://github.com/hanakai-rb/rom-sql/compare/v2.5.0...v3.0.0

## [2.5.0] - 2018-06-08

### Added

- Support for subqueries in `SELECT` and `WHERE` :tada: (flash-gordon)
  ```ruby
  tasks = relations[:tasks]
  users = relations[:users]
  user_tasks = tasks.where(tasks[:user_id].is(users[:id])
  tasks_count = user_tasks.select { integer::count(id) }.query
  users.select_append(tasks_count.as(:tasks_count))
  ```

[2.5.0]: https://github.com/hanakai-rb/rom-sql/compare/v2.4.0...v2.5.0

## [2.4.0] - 2018-02-18

### Added

- Support for functions with `Any` return type (GustavoCaso)
- New `Relation#as_hash` method (GustavoCaso)

[2.4.0]: https://github.com/hanakai-rb/rom-sql/compare/v2.3.0...v2.4.0

## [2.3.0] - 2017-11-17

### Added

- Command's `:timestamp` plugin now supports passing options (GustavoCaso)
- Configuration supports hash with connection options (Kjarrigan + solnic)

### Fixed

- Aliased attributes are handled correctly in PG's commands (cflipse)
- Command extensions are properly applied in multi-adapter setups (solnic)

[2.3.0]: https://github.com/hanakai-rb/rom-sql/compare/v2.2.1...v2.3.0

## [2.2.1] - 2017-11-10

### Fixed

- Instrumentation works with all db interactions (not just queries that materialize relations) (solnic)
- Typo in `MissingEnv` exception message (romatr)

[2.2.1]: https://github.com/hanakai-rb/rom-sql/compare/v2.2.0...v2.2.1

## [2.2.0] - 2017-11-02

### Added

- Relation registry is passed as an argument to DSL blocks (in `select`, `where`, `order` etc.), which enables syntax like `select { |r| [id, r.tasks[:title]] }` (solnic)
- Support for self-referenced many-to-many associations (solnic)
- PG's geometric types include meta data about db types (GustavoCaso)

### Fixed

- Custom schema is used correctly in command results (solnic)
- Schemas no longer finalize PKs (this is done in core schema already) (solnic)

[2.2.0]: https://github.com/hanakai-rb/rom-sql/compare/v2.1.0...v2.2.0

## [2.1.0] - 2017-10-23

### Added

- Support for PG's range types (v-kolesnikov)
- Support for PG's `ltree` (GustavoCaso + solnic)
- Support for the `FILTER` clause (flash-gordon)
- PG's array types will use custom types for processing members ie `ltree[]` will use `LTree` type (solnic)

### Fixed

- Schema inference works with primary keys that have custom types (ie an enum PK column) (v-kolesnikov)
- Ruby warnings are gone (solnic)

[2.1.0]: https://github.com/hanakai-rb/rom-sql/compare/v2.0.0...v2.1.0

## [2.0.0] - 2017-10-18

### Added

- Support for schema plugins (flash-gordon)
- Support for auto migrations (flash-gordon)
- Add DLS for describing table indexes (flash-gordon)

  ```ruby
    schema do
      indexes do
        index :name, name: :unique_name, unique: true
        index :props, type: :gin
        index :name, name: :long_names_only, predicate: 'length(name) > 10'
        index :user_id, :title, name: :composite_idx
      end
    end
  ```
- Support for composite indexes in the auto-restrictions plugin (flash-gordon)
- `SQL::Gateway#call` calls a SQL function (flash-gordon)

  ```ruby
    gateway.(:upper, 'foo') # => "FOO"
    gateway.(:pg_advisory_xact_lock, 1234) # => nil
  ```
- `SQL::Gateway#run` executes a SQL string, e.g. a DDL statement (flash-gordon)

  ```ruby
    gateway.run('set session IntervalStyle to default')
  ```
- `SQL::Relation#exists` joins a relation with the `EXISTS` operator (flash-gordon)

  ```ruby
    users.exists(posts) # => users with posts
  ```
- Support for processing a relation in batches (flash-gordon)

  ```ruby
    users.each_batch(size: 100) do |rel|
      rel.
        command(:update).
        call(name: users[:first_name].concat(users[:last_name])
    end
  ```
- `SQL::Relation#import` inserts data from another relation using the `INSERT ... AS SELECT` syntax which is often far more effective than row-by-row processing and an ordinary multi-insert. Relations defined on another gateway are also supported, and in this case, the implementation falls back to the multi-insert strategy (flash-gordon)

  ```ruby
    users.import(authors.select { first_name.concat(last_name).as(:name) })
  ```
- Support for `tinytext`, `text`, `mediumtext`, and `longtext data types in MySQL (panthomakos)
- The new `pg_explain` plugin for getting query plans on PostgreSQL (flash-gordon)

  ```ruby
    users.by_pk(1).explain(format: :json, analyze: true)
  ```
- Support for window function calls

  ```ruby
    employees.select { [dep_no, salary, integer::avg(salary).over(partition: dep_no, order: id).as(:avg_salary)] }
  ```
- Function result can be negated, also `ROM::SQL::Function#not` was added (flash-gordon)

  ```ruby
     users.where { !lower(name).is('John') }
     users.where { lower(name).not('John') }
  ```

### Changed

- [BREAKING] based on rom 4.0 now (flash-gordon + solnic)
- [BREAKING] `Associates` command plugin requires associations now (solnic)
- [BREAKING] `Command#transaction` is gone in favor of `Relation#transaction` (solnic)
- [BREAKING] `PG::JSONArray`, `PG::JSONBArray`, `PG::JSONHash`, and `PG::JSONBHash` types were dropped, use `PG::JSON` and `PG::JSONB` instead (flash-gordon)
- [BREAKING] The `pg_hstore` extension now doesn't get loaded automatically, use the `:extension` option to load it on config initialization (flash-gordon)
- `ManyToOne` no longer uses a join (solnic)
- `AutoCombine` and `AutoWrap` plugins were removed as this functionality is provided by core API (solnic)
- Foreign keys are indexed by default (flash-gordon)
- Schemas are qualified by default (solnic)
- `PG::JSON`, `PG::JSONB`, and `PG::Array` now all have read types so that they return plain Hash/Array values instead of Sequel's wrappers (flash-gordon)

### Fixed

- Self-ref associations work correctly with custom FKs (solnic)
- Aliased associations with custom FKs work correctly (solnic)
- Defining a custom dataset block no longer prevents default views like `by_pk` to be defined (solnic)
- `Relation#group` uses canonical schema now (solnic)

[2.0.0]: https://github.com/hanakai-rb/rom-sql/compare/v1.3.3...v2.0.0

## [1.3.5] - 2017-10-12

### Changed

- Added compatibility with `dry-types` 0.11 (flash-gordon)

[1.3.5]: https://github.com/hanakai-rb/rom-sql/compare/v1.3.4...v1.3.5

## [1.3.4] - 2017-09-12

### Fixed

- A warning caused by using `EMPTY_BRACKET` from Sequel (flash-gordon)

[1.3.4]: https://github.com/hanakai-rb/rom-sql/compare/v1.3.3...v1.3.4

## [1.3.3] - 2017-05-30

### Added

- `Relation#lock`, row-level locking using the `SELECT FOR UPDATE` clause (flash-gordon)
- `get` and `get_text` methods for the `PG::JSON` type (flash-gordon)
- Support for converting data type with `CAST` using the function DSL (flash-gordon)

  ```ruby
    users.select { string::cast(id, 'varchar').as(:id_str) }
  ```
- Support for`EXISTS` (v-kolesnikov)

  ```ruby
    subquery = tasks.where(tasks[:user_id].qualified => users[:id].qualified)
    users.where { exists(subquery) }
  ```

### Fixed

- Fixed a regression introduced in v1.3.2 caused by doing way more work processing the default dataset (flash-gordon)

[1.3.3]: https://github.com/hanakai-rb/rom-sql/compare/v1.3.2...v1.3.3

## [1.3.2] - 2017-05-13

### Added

- Support for filtering with a SQL function in the `WHERE` clause. Be sure you're using it wisely and don't call it on large datasets ;) (flash-gordon)
- `Void` type for calling functions without returning value (flash-gordon)
- Support for [`PG::Array` transformations and queries](https://github.com/rom-rb/rom-sql/blob/15019a40e2cf2a224476184c4cddab4062a2cc01/lib/rom/sql/extensions/postgres/types.rb#L23-L148) (flash-gordon)

### Fixed

- A bunch of warnings from Sequel 4.46

[1.3.2]: https://github.com/hanakai-rb/rom-sql/compare/v1.3.1...v1.3.2

## [1.3.1] - 2017-05-05

### Changed

- [internal] Compatibility with `dry-core` v0.3.0 (flash-gordon)

[1.3.1]: https://github.com/hanakai-rb/rom-sql/compare/v1.3.0...v1.3.1

## [1.3.0] - 2017-05-02

### Added

- New `Relation#exist?` predicate checks if the relation has at least one tuple (flash-gordon)
- Support for [JSONB transformations and queries](https://github.com/rom-rb/rom-sql/blob/15019a40e2cf2a224476184c4cddab4062a2cc01/lib/rom/sql/extensions/postgres/types.rb#L170-L353) using native DSL (flash-gordon)
- Add `ROM::SQL::Attribute#not` for negated boolean equality expressions (AMHOL)
- Add `ROM::SQL::Attribute#!` for negated attribute's sql expressions (solnic)
- Inferrer gets limit constraints for string data types and stores them in type's meta (v-kolesnikov)

### Changed

- Global private interface `SQL::Gateway.instance` has been deprecated. Now if you run migrations
  with ROM you should set up a ROM config in the `db:setup` task with something similar to

  ```ruby
    namespace :db
      task :setup do
        ROM::SQL::RakeSupport.env = ROM::Configuration.new(:sql, ENV['DATABASE_URL'])
      end
    end
  ```

### Fixed

- Fixed usage of PostgreSQL's commands with a composite relation (flash-gordon)
- Translation of `true/false/nil` equality checks to `is/is not` SQL statements in `ROM::SQL::Attribute#is` (AMHOL)
- `associates` command plugin coerces parent collections to hashes correctly (aarek+solnic)
- `by_pk` works correctly even when PK is not projected (solnic)

[1.3.0]: https://github.com/hanakai-rb/rom-sql/compare/v1.2.2...v1.3.0

## [1.2.2] - 2017-03-25

### Changed

- Updated `dry-initializer` (flash-gordon)

[1.2.2]: https://github.com/hanakai-rb/rom-sql/compare/v1.2.1...v1.2.2

## [1.2.1] - 2017-03-09

### Fixed

- Allow for joining by a `RelationProxy` instance from `rom-repository` (davydovanton)

[1.2.1]: https://github.com/hanakai-rb/rom-sql/compare/v1.2.0...v1.2.1

## [1.2.0] - 2017-03-07

### Added

- Support for configuring multiple associations for a command (solnic)
- Support for passing parent tuple(s) as `parent` option in `Command#with_association` (solnic)
- Support for join using assocation name (flash-gordon)

[1.2.0]: https://github.com/hanakai-rb/rom-sql/compare/v1.1.2...v1.2.0

## [1.1.2] - 2017-03-02

### Fixed

- Fix grouping by a function in the block DSL (flash-gordon)

[1.1.2]: https://github.com/hanakai-rb/rom-sql/compare/v1.1.1...v1.1.2

## [1.1.1] - 2017-03-01

### Fixed

- Restriction conditions with an array as a value are handled correctly by attribute types (solnic)

[1.1.1]: https://github.com/hanakai-rb/rom-sql/compare/v1.1.0...v1.1.1

## [1.1.0] - 2017-03-01

### Added

- Added inferring for database indices (flash-gordon)
- Restriction conditions are now coerced using schema attributes (solnic)
- `:instrumentation` relation plugin that can be configured with any instrumentation backend (solnic)
- `:auto_restrictions` relation plugin, which defines `by_*` views restricting relations by their indexed attributes (solnic)

### Fixed

- Missing `group` method was added to legacy `SequelAPI` module (solnic)
- Associations properly maintain `order` if it was set (solnic)

[1.1.0]: https://github.com/hanakai-rb/rom-sql/compare/v1.0.3...v1.1.0

## [1.0.3] - 2017-02-23

### Changed

- `AutoCombine#preload` uses better restriction for `ManyToOne` association which greatly speeds up loading bigger amounts of data (solnic + flash-gordon)

### Fixed

- Fix the usage of timestamp in command chains (cflipse)

[1.0.3]: https://github.com/hanakai-rb/rom-sql/compare/v1.0.2...v1.0.3

## [1.0.2] - 2017-02-16

### Added

- Support for selecting literal strings via `` select { `'foo'`.as(:bar) } `` (solnic)

[1.0.2]: https://github.com/hanakai-rb/rom-sql/compare/v1.0.1...v1.0.2

## [1.0.1] - 2017-02-09

### Added

- Support for inferring the PostgreSQL `hstore` data type (flash-gordon)
- Support for the rest of geometric PostgreSQL data types (box, lseg, polygon, etc.) (Morozzzko)
- Added inferring for timestamp types with specified precision (flash-gordon)
- Added `ROM::SQL::Attribute#in` to support range checks in conditions (flash-gordon)

### Fixed

- Missing primary key now leads to a more meaningful error (flash-gordon)

[1.0.1]: https://github.com/hanakai-rb/rom-sql/compare/v1.0.0...v1.0.1

## [1.0.0] - 2017-01-29

Please refer to [the upgrading guide](https://github.com/rom-rb/rom-sql/wiki/Upgrading-from-0.9.x-to-1.0.0) if you're moving from 0.9.x to 1.0.0.

### Added

- [BREAKING] All relations have schemas (inferred by default, but still possible to override and/or extend) (solnic)
- [BREAKING] Schemas are used when defining relation views (solnic)
- [BREAKING] Default dataset is set up based on schema (solnic)
- Extended query API with support for schema attributes (solnic)
- Schemas can project relations automatically (solnic)
- New `Schema#qualified` (solnic)
- New `Relation#assoc` method which is a shortcut for accessing relation created by the given association (solnic)
- Schema attribute types are now SQL-specific and compatible with query DSL (ie you can pass relation attributes to `select` and they will be automatically converted to valid SQL expressions) (solnic)
- Associations support setting custom `view` that will be used to extend association relation (solnic)
- Associations support setting custom `foreign_key` names (solnic)
- Update commands has `:associates` plugin enabled (solnic)
- Support for self-referencing associations (ie categories have_many child categories) (solnic)
- Inferrers for mysql and sqlite were added (flash-gordon)
- PG's auto-inferrer can handle `inet`/`cidr`/`point` data types in a two-way manner, i.e. converting them back and forth on reading and writing (flash-gordon)
- Support for inferring more PG types: `macaddr`, `xml` (flash-gordon)
- `ROM::SQL::Relation::SequelAPI` extension for backward-compatible query API (this will be deprecated in 1.1.0 and removed in 2.0.0) (solnic)
- Added `Object` type for `SQLite` which is used by the inferrer for columns without a type affinity (flash-gordon)
- Support for composite PKs in the default `by_pk` view (solnic)

### Changed

- [BREAKING] `Relation#header` has been removed in favor of schemas (solnic)
- [BREAKING] `Relation#base` has been removed as now a vanilla relation _is a base relation view_ (solnic)
- [BREAKING] Deprecated `Relation.primary_key` has been removed in favor of schema (solnic)
- [BREAKING] Deprecated `Commands::Update#change` has been removed (solnic)
- [BREAKING] Deprecated `Commands.validator` has been removed (solnic)
- [BREAKING] `assoc_macros` plugin has been removed, please use associations from now (solnic)
- Default `by_pk` uses schema attributes, it will raise exception if PK attribute is missing in the schema (solnic)
- [internal] Associations use schemas for relation projections (solnic)
- [internal] `select`, `select_append`, `project`, `inner_join` and `left_join` use schemas internally (solnic)
- [internal] Deprecation and constants are now based on dry-core (flash-gordon)

[1.0.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.9.1...v1.0.0

## [0.9.1] - 2016-12-23

### Added

- Support for PG enums in schema inferrer (flash-gordon)
- `ROM::SQL::Relation#read` method which accepts an SQL string and returns a new relation (solnic)

[0.9.1]: https://github.com/hanakai-rb/rom-sql/compare/v0.9.0...v0.9.1

## [0.9.0] - 2016-11-08

### Added

- `Associations::{OneToMany,OneToOne}#associate` for merging FKs into child tuple (jodosha)
- Added support for PostgreSQL types: UUID, Array, JSONB and Money (jodosha)
- Support for DB specific schema inferrers (flash-gordon)
- Automatically infer PG arrays and JSON(B) types (jodosha + flash-gordon)
- Support for `Relation#having` (cflipse)

### Changed

- Inferred types in schemas **are no longer strict** (flash-gordon)
- PG-specific types are handled by `:postgres` extension and it loads connection extensions automatically (flash-gordon)
- Make `OneToOne` inherit from `OneToMany` (beauby)
- Default dataset will use column names from schema if it's available (solnic)

### Fixed

- Floats are inferred by schemas (cflipse)

[0.9.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.8.0...v0.9.0

## [0.8.0] - 2016-07-27

### Added

- Support for relation schemas with SQL-specific data types (solnic + flash-gordon)
- One-To-Many support in schemas (solnic + flash-gordon)
- One-To-One support in schemas (solnic + flash-gordon)
- One-To-One-Through support in schemas (solnic + flash-gordon)
- Many-To-One support in schemas (solnic + flash-gordon)
- Many-To-Many support in schemas (solnic + flash-gordon)
- Support for `has_many`, `has_one` and `belongs_to` convenient methods in schema DSL (solnic)
- Support for custom PG types: `Types::PG::Array`, `Types::PG::Hash`, `Types::PG::JSON`, and `Types::PG::Bytea` (solnic + flash-gordon)
- Optional automatic schema inference for attributes and foreign keys based on DB metadata provided by Sequel (flash-gordon)
- Support for arbitrary dataset and FK names in schemas (flash-gordon)
- Support for native upserts in PostgreSQL >= 9.5 via `Commands::Postgres::Upsert` (gotar + flash-gordon)

### Changed

- `Create` and `Update` commands have `:schema` plugin enabled by default which sets input handler based on schema definition automatically (solnic)
- `associates` command plugin uses schema associations now (solnic)
- Dropped MRI 2.0.x support

### Fixed

- `Create` command properly materialize result when `:one` is set (AMHOL)

[0.8.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.7.0...v0.8.0

## [0.7.0] - 2016-01-06

### Added

- Repository plugins have been imported:
  - `view` allows defining a relation view with an explicit header (solnic)
  - `base_view` defines a base view with all column names as the header (solnic)
  - `auto_combine` defines a generic `for_combine` method which eager-loads
    parent/children relation (solnic)
  - `auto-wrap` defines a generic `for_wrap` method which inner-joins
    a parent/children relation (solnic)
- Possibility to check for pending migrations (gotar)
- `Relation#sum` interface (gotar)
- `Relation#avg` interface (gotar)
- `Relation#min` interface (gotar)
- `Relation#max` interface (gotar)
- `Relation#union` interface (spscream)
- `primary_key` macro which allows setting a custom primary key when it cannot be
  inferred automatically (solnic)

### Changed

- `ROM::SQL.gateway` renamed to `ROM::SQL::Gateway.instance` for migrations (endash)
- Association macros are now an optional plugin (solnic)

[0.7.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.6.1...v0.7.0

## [0.6.1] - 2015-09-23

### Added

- `Gateway` accepts `:extensions` as an option (c0)

[0.6.1]: https://github.com/hanakai-rb/rom-sql/compare/v0.6.0...v0.6.1

## [0.6.0] - 2015-08-19

Internal updates to fix deprecation warnings from ROM 0.9.0.

[0.6.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.5.3...v0.6.0

## [0.5.3] - 2015-07-23

### Added

- `Relation#multi_insert` (draxxxeus)

### Changed

- Command that receives many tuples will use `multi_insert` now (draxxxeus)

### Fixed

- Relation name and join key fixes for `many_to_one` macro (jamesmoriarty)

[0.5.3]: https://github.com/hanakai-rb/rom-sql/compare/v0.5.2...v0.5.3

## [0.5.2] - 2015-06-22

### Added

- `Relation#invert` operation (nepalez)

### Changed

- Migration tasks no longer require entire ROM env (solnic)
- `Repository` => `Gateway` rename for ROM 0.8.0 compatibility (solnic)

[0.5.2]: https://github.com/hanakai-rb/rom-sql/compare/v0.5.1...v0.5.2

## [0.5.1] - 2015-05-25

### Changed

- Relations won't be finalized when table(s) is/are missing (solnic)

### Fixed

- Wrap errors when calling commands with `[]`-syntax (kwando)

[0.5.1]: https://github.com/hanakai-rb/rom-sql/compare/v0.5.0...v0.5.1

## [0.5.0] - 2015-05-22

### Added

- Association macros support addition `:on` option (solnic)
- `associates` plugin for `Create` command (solnic)
- Support for NotNullConstraintError (solnic)
- Support for UniqueConstraintConstraintError (solnic)
- Support for ForeignKeyConstraintError (solnic)
- Support for CheckConstraintError (solnic)
- `Commands::Update#original` supports objects coercible to_h now (solnic)

### Changed

- [BREAKING] Constraint errors are no longer command errors which means `try` and
  `transaction` blocks will not catch them (solnic)
- `Commands::Update#set` has been deprecated (solnic)
- `Commands::Update#to` has been deprecated (solnic)

[0.5.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.4.3...v0.5.0

## [0.4.3] - 2015-05-17

### Fixed

- `transaction` doesn't swallow errors now other than CommandError (solnic)

[0.4.3]: https://github.com/hanakai-rb/rom-sql/compare/v0.4.2...v0.4.3

## [0.4.2] - 2015-05-17

### Added

- Support for setting custom association name (solnic)
- Support for `:conditions` option in association definition (solnic)
- Better error message when accessing undefined associations (pdswan)

### Changed

- `transaction` returns command failure objects when there was a rollback (solnic)

### Fixed

- Correct `ROM::SQL::Plugin::Pagination::Pager#total_pages` when total is not
  evenly divisible by page size (larribas)
- `association_join` behaves correctly when dataset is different than register_as (nepalez)

[0.4.2]: https://github.com/hanakai-rb/rom-sql/compare/v0.4.1...v0.4.2

## [0.4.1] - 2015-04-04

### Added

- Database error handling for update and delete commands (kwando + solnic)
- Migration interface as a repository plugin (gotar + solnic)

[0.4.1]: https://github.com/hanakai-rb/rom-sql/compare/v0.4.0...v0.4.1

## [0.4.0] - 2015-03-22

### Added

- `ROM::SQL::Relation` which explictly defines an interface on top of Sequel (solnic + mcls)
- Postgres-specific Create and Update commands that support RETURNING (gotar + solnic)
- `Update#change` interface for skipping execution when there's no diff (solnic)
- Experimental migration API using sequel/migrations (gotar)
- Pagination plugin (solnic)
- Allow reuse of established Sequel connections (splattael)

### Changed

- Use ROM's own inflector which uses either ActiveSupport or Inflecto backends (mjtko)

### Fixed

- Indentation in Rails logger (morgoth)

[0.4.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.3.2...v0.4.0

## [0.3.2] - 2015-01-01

### Fixed

- Checking tuple count in commands (solnic)

[0.3.2]: https://github.com/hanakai-rb/rom-sql/compare/v0.3.1...v0.3.2

## [0.3.1] - 2014-12-31

### Added

- `Adapter#disconnect` (solnic)
- Support for extra connection options (solnic)

[0.3.1]: https://github.com/hanakai-rb/rom-sql/compare/v0.3.0...v0.3.1

## [0.3.0] - 2014-12-19

### Changed

- `association_join` now uses Sequel's `graph` interface which qualifies columns automatically (solnic)
- Delete command returns deleted tuples (solnic)

[0.3.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.2.0...v0.3.0

## [0.2.0] - 2014-12-06

### Added

- Command API (solnic)
- Support for ActiveSupport::Notifications with a log subscriber (solnic)
- New `ROM::SQL::Adapter#dataset?(name)` checking if a given table exists (solnic)

[0.2.0]: https://github.com/hanakai-rb/rom-sql/compare/v0.1.1...v0.2.0

## [0.1.1] - 2014-11-24

### Changed

- minor refactor in adapter (solnic)

### Fixed

- Equalizer in header (solnic)

[0.1.1]: https://github.com/hanakai-rb/rom-sql/compare/v0.1.0...v0.1.1

## [0.1.0] - 2014-11-24

First release powered by Sequel

[0.1.0]: https://github.com/hanakai-rb/rom-sql/tree/v0.1.0
