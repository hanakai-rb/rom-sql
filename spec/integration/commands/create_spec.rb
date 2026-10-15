# frozen_string_literal: true

require 'dry-struct'

RSpec.describe 'Commands / Create', :postgres, seeds: false do
  include_context 'relations'

  let(:profile_commands) { container.commands[:profiles] }

  let(:create_user) { user_commands.create }
  let(:create_users) { user_commands.create_many }
  let(:create_task) { task_commands.create }
  let(:create_profile) { profile_commands.create }

  setup_relations do
    module Test
      class Params < Dry::Struct
        attribute :name, Types::Strict::String.optional

        def self.[](input)
          new(input)
        end
      end
    end
  end

  setup_tables do |ex|
    conn.add_index :users, :name, unique: true

    if sqlite?(ex)
      conn.add_index :tasks, :title, unique: true
    else
      conn.execute 'ALTER TABLE tasks add CONSTRAINT tasks_title_key UNIQUE (title)'
    end
  end

  setup_relations do
    conf.relation(:profiles) do
      schema(:users, infer: true) do
        attribute :name, Types::String, alias: :login
      end
    end

    conf.commands(:users) do
      define(:create) do
        input Test::Params

        result :one
      end

      define(:create_many, type: :create) do
        result :many
      end
    end

    conf.commands(:profiles) do
      define(:create)
    end

    conf.commands(:tasks) do
      define(:create)
    end
  end

  with_adapters do
    describe '#transaction' do
      it 'creates record if nothing was raised' do
        result = users.transaction {
          create_user.call(name: 'Jane')
        }

        expect(result).to eql(id: 1, name: 'Jane')
      end

      it 'creates multiple records if nothing was raised' do
        result = users.transaction {
          create_users.call([{ name: 'Jane' }, { name: 'Jack' }])
        }

        expect(result).to match_array([
          { id: 1, name: 'Jane' }, { id: 2, name: 'Jack' }
        ])
      end

      it 'allows for nested transactions' do
        result = users.transaction {
          users.transaction {
            create_user.call(name: 'Jane')
          }
        }

        expect(result).to eql(id: 1, name: 'Jane')
      end

      it 'creates nothing if command error was raised' do
        expect {
          begin
            users.transaction {
              create_user.call(name: 'Jane')
              create_user.call(name: nil)
            }
          rescue ROM::SQL::Error
            # ignore
          end
        }.to_not(change { container.relations.users.count })
      end

      it 'creates nothing if rollback was raised' do
        expect {
          result = users.transaction { |t|
            create_user.call(name: 'Jane')
            create_user.call(name: 'John')
            t.rollback!
          }

          expect(result).to be(nil)
        }.to_not(change { container.relations.users.count })
      end

      it 'creates nothing if constraint error was raised' do
        expect {
          begin
            passed = false

            users.transaction {
              create_user.call(name: 'Jane')
              create_user.call(name: 'Jane')
              passed = true
            }
          rescue StandardError => e
            expect(e).to be_instance_of(ROM::SQL::UniqueConstraintError)
            expect(passed).to be(false)
          end
        }.to_not(change { container.relations.users.count })
      end

      it 'creates nothing if anything was raised in any nested transaction' do
        expect {
          expect {
            users.transaction {
              create_user.call(name: 'John')

              users.transaction {
                create_user.call(name: 'Jane')
                raise Exception
              }
            }
          }.to raise_error(Exception)
        }.to_not(change { container.relations.users.count })
      end
    end

    context 'when using relation schema for the default input handler' do
      setup_relations do
        conf.relation(:users_with_schema) do
          schema(:users) do
            attribute :id, ROM::SQL::Types::Serial
            attribute :name, ROM::SQL::Types::String
          end
        end

        conf.commands(:users_with_schema) do
          define(:create) do
            result :one
          end
        end
      end

      specify do
        create = container.commands[:users_with_schema][:create]

        expect(create.input[foo: 'bar', id: 1, name: 'Jane']).to eql(
          id: 1, name: 'Jane'
        )
      end
    end

    it 'returns a single tuple when result is set to :one' do
      result = create_user.call(name: 'Jane')

      expect(result).to eql(id: 1, name: 'Jane')
    end

    it 'returns tuples when result is set to :many' do
      result = create_users.call([{ name: 'Jane' }, { name: 'Jack' }])

      expect(result.to_a).to match_array([
        { id: 1, name: 'Jane' }, { id: 2, name: 'Jack' }
      ])
    end

    it 're-raises not-null constraint violation error' do
      expect {
        create_user.call(name: nil)
      }.to raise_error(ROM::SQL::NotNullConstraintError)
    end

    context 'with json notes' do
      include_context 'json_notes'

      setup_relations do
        conf.commands(:json_notes) do
          define(:create)
        end
      end

      it 'writes and reads back custom type' do
        json_notes = commands[:json_notes]

        expect(json_notes[:create].call(note: 'this is my note')).to eq([{ id: 1, note: 'this is my note' }])
      end
    end

    # Because Oracle doesn't have boolean in SQL
    unless metadata[:oracle]
      context 'with puppies' do
        include_context 'puppies'

        setup_relations do
          conf.relation(:puppies) do
            schema(infer: true)
          end

          conf.commands(:puppies) do
            define(:create)
          end
        end

        it 're-raises not-null constraint violation error with nil boolean' do
          puppies = commands[:puppies]

          expect {
            puppies.create.call(name: 'Charlie', cute: nil)
          }.to raise_error(ROM::SQL::NotNullConstraintError)
        end
      end
    end

    it 'raises uniqueness constraint violation error' do
      expect {
        user = create_user.call(name: 'Jane')
        create_user.call(name: user[:name])
      }.to raise_error(ROM::SQL::UniqueConstraintError)
    end

    it 're-raises fk constraint violation error' do |_ex|
      expect {
        create_task.call(user_id: 918_273_645)
      }.to raise_error(ROM::SQL::ForeignKeyConstraintError)
    end

    it 're-raises database errors' do
      expect {
        create_user.call(name: nil)
      }.to raise_error(ROM::SQL::NotNullConstraintError)
    end

    describe '#execute' do
      context 'with a single record' do
        it 'materializes the result' do
          result = create_user.execute(name: 'Jane')

          expect(result).to eq([{ id: 1, name: 'Jane' }])
        end

        it 'materializes aliased results' do
          result = create_profile.execute(name: 'Joe')
          expect(result).to eq([{ id: 1, login: 'Joe' }])
        end
      end

      context 'with multiple records' do
        it 'materializes the results' do
          result = create_user.execute([
            { name: 'Jane' },
            { name: 'John' }
          ])

          expect(result).to eql([{ id: 1, name: 'Jane' }, { id: 2, name: 'John' }])
        end
      end

      context 'with a composite pk' do
        before do
          inferrable_relations.push(:user_group)
        end

        setup_tables do
          conn.create_table(:user_group) do
            primary_key [:user_id, :group_id]
            column :user_id, Integer, null: false
            column :group_id, Integer, null: false
          end
        end

        setup_relations do
          conf.relation(:user_group) do
            schema(infer: true)
          end

          conf.commands(:user_group) do
            define(:create) { result :one }
          end
        end

        # with a composite pk sequel returns 0 when inserting for MySQL
        unless metadata[:mysql]
          it 'materializes the result' do |ex|
            command = container.commands[:user_group][:create]
            result = command.call(user_id: 1, group_id: 2)

            pending "if sequel could use Oracle's RETURNING statement, that would be possible" if oracle?(ex)
            expect(result).to eql(user_id: 1, group_id: 2)
          end
        end
      end
    end
  end

  describe '#call' do
    it 'raises check constraint violation error' do
      expect {
        create_user.call(name: 'J')
      }.to raise_error(ROM::SQL::CheckConstraintError, /name/)
    end

    it 'raises constraint violation error' do
      expect { create_task.call(title: '') }.to raise_error(ROM::SQL::ConstraintError, /title/)
    end
  end

  describe '#upsert' do
    let(:task) { { title: 'task 1' } }

    seed { create_task.call(task) }

    it 'raises error without upsert marker' do
      expect {
        create_task.call(task)
      }.to raise_error(ROM::SQL::UniqueConstraintError)
    end

    it 'raises no error for duplicated data' do
      expect { create_task.upsert(task) }.to_not raise_error
    end

    it 'returns record data' do
      expect(create_task.upsert(task, constraint: :tasks_title_key, update: { user_id: nil })).to eql([
        id: 1, user_id: nil, title: 'task 1'
      ])
    end
  end

  describe 'on a relation with conflict handling' do
    let(:task) { { title: 'task 1' } }

    seed do
      create_user.call(name: 'Jane')
      create_task.call(task)
    end

    it 'returns nothing when the conflict is ignored' do
      expect(tasks.on_conflict(:title).command(:create).call(task)).to eql([])
    end

    it 'returns the updated tuple' do
      command = tasks.on_conflict(:title).do_update(:user_id).command(:create)

      expect(command.call(task.merge(user_id: 1))).to eql([{ id: 1, user_id: 1, title: 'task 1' }])
    end

    it 'returns inserted and updated tuples' do
      command = tasks.on_conflict(:title).do_update(:user_id).command(:create)

      expect(command.call([task.merge(user_id: 1), title: 'task 2', user_id: 1])).to match([
        { id: 1, user_id: 1, title: 'task 1' },
        hash_including(user_id: 1, title: 'task 2')
      ])
    end

    it 'leaves the plain command failing on conflict' do
      expect { tasks.command(:create).call(task) }.to raise_error(ROM::SQL::UniqueConstraintError)
    end
  end
end
