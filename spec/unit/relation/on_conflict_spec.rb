# frozen_string_literal: true

RSpec.describe ROM::Relation, '#on_conflict' do
  subject(:relation) { relations[:tasks] }

  include_context 'users and tasks'

  let(:joes_task) { { id: 1, user_id: 2, title: "Joe's task" } }

  # tasks are seeded with explicit ids
  seed do |example|
    conn.run("SELECT setval('tasks_id_seq', (SELECT max(id) FROM tasks))") if postgres?(example)
  end

  with_adapters(:postgres, :sqlite) do
    context 'with a unique constraint' do
      setup_tables do |example|
        if sqlite?(example)
          conn.add_index :tasks, :title, unique: true
        else
          conn.run 'ALTER TABLE tasks ADD CONSTRAINT tasks_title_key UNIQUE (title)'
        end
      end

      it 'does nothing on conflict with the target' do
        relation.on_conflict(:title).insert(user_id: 1, title: "Joe's task")

        expect(relation.by_pk(1).one).to eql(joes_task)
        expect(relation.count).to be(2)
      end

      it 'does nothing on conflict with any constraint' do
        relation.on_conflict.insert(user_id: 1, title: "Joe's task")

        expect(relation.by_pk(1).one).to eql(joes_task)
        expect(relation.count).to be(2)
      end

      it 'accepts attributes as the target' do
        relation.on_conflict(relation[:title]).insert(user_id: 1, title: "Joe's task")

        expect(relation.by_pk(1).one).to eql(joes_task)
      end

      it 'inserts rows that do not conflict' do
        relation.on_conflict(:title).insert(user_id: 1, title: 'Another task')

        expect(relation.count).to be(3)
      end

      it 'handles conflicts in multi_insert' do
        relation.on_conflict(:title).multi_insert(
          [{ user_id: 1, title: "Joe's task" }, { user_id: 1, title: 'Another task' }]
        )

        expect(relation.by_pk(1).one).to eql(joes_task)
        expect(relation.count).to be(3)
      end

      it 'resets a previous do_update with do_nothing' do
        relation.on_conflict(:title).do_update(:user_id).do_nothing.insert(user_id: 1, title: "Joe's task")

        expect(relation.by_pk(1).one).to eql(joes_task)
      end

      it 'keeps the insert failing without on_conflict' do
        expect {
          relation.insert(user_id: 1, title: "Joe's task")
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    context 'with a partial unique index' do
      setup_tables do
        conn.run 'CREATE UNIQUE INDEX tasks_title_partial_index ON tasks (title) WHERE user_id = 1'
      end

      it 'infers the index from the predicate in the block' do
        relation.on_conflict(:title) { user_id.is(1) }.insert(user_id: 1, title: "Jane's task")

        expect(relation.where(title: "Jane's task").count).to be(1)
      end

      it 'inserts rows outside the predicate' do
        relation.on_conflict(:title) { user_id.is(1) }.insert(user_id: 2, title: "Jane's task")

        expect(relation.where(title: "Jane's task").count).to be(2)
      end

      it 'infers the index from a predicate passed as where' do
        relation.on_conflict(:title, where: relation[:user_id].is(1)).insert(user_id: 1, title: "Jane's task")

        expect(relation.where(title: "Jane's task").count).to be(1)
      end

      it 'accepts a hash predicate as where' do
        relation.on_conflict(:title, where: { user_id: 1 }).insert(user_id: 1, title: "Jane's task")

        expect(relation.where(title: "Jane's task").count).to be(1)
      end

      it 'reaches a column a local variable of the same name would shadow in a block' do
        user_id = 1

        relation.on_conflict(:title, where: relation[:user_id].is(user_id)).insert(user_id:, title: "Jane's task")

        expect(relation.where(title: "Jane's task").count).to be(1)
      end

      it 'raises when the predicate is given both as where and as a block' do
        expect {
          relation.on_conflict(:title, where: { user_id: 1 }) { user_id.is(1) }
        }.to raise_error(ArgumentError, /either as where: or as a block/)
      end
    end
  end

  with_adapters(:postgres) do
    setup_tables do
      conn.run 'ALTER TABLE tasks ADD CONSTRAINT tasks_title_key UNIQUE (title)'
    end

    it 'does nothing on conflict with a named constraint' do
      relation.on_conflict(constraint: :tasks_title_key).insert(user_id: 1, title: "Joe's task")

      expect(relation.by_pk(1).one).to eql(joes_task)
    end
  end

  with_adapters(:mysql) do
    it 'raises an error when the database does not support ON CONFLICT' do
      expect {
        relation.on_conflict(:title)
      }.to raise_error(ROM::SQL::UnsupportedFeatureError, /ON CONFLICT is not supported by mysql/)
    end
  end
end
