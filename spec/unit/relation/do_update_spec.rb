# frozen_string_literal: true

RSpec.describe ROM::Relation, '#do_update' do
  subject(:relation) { relations[:tasks] }

  include_context 'users and tasks'

  # tasks are seeded with explicit ids
  seed do |example|
    conn[:users].insert name: 'Jack'
    conn.run("SELECT setval('tasks_id_seq', (SELECT max(id) FROM tasks))") if postgres?(example)
  end

  with_adapters(:postgres, :sqlite) do
    setup_tables do
      conn.add_index :tasks, :title, unique: true
    end

    let(:conflicting) { relation.on_conflict(:title) }

    let(:joes_task) { relation.by_pk(1).one }

    it 'updates every column but the key and the target from the excluded row' do
      conflicting.do_update.insert(user_id: 1, title: "Joe's task")

      expect(joes_task).to eql(id: 1, user_id: 1, title: "Joe's task")
    end

    it 'updates listed columns from the excluded row' do
      conflicting.do_update(:user_id).insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'sets literal values' do
      conflicting.do_update(user_id: nil).insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be_nil
    end

    it 'sets expressions built outside the DSL' do
      conflicting.do_update(user_id: relation.excluded[:user_id]).insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'accepts a hash returned from the block' do
      conflicting.do_update { { user_id: excluded[:user_id] } }.insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'sets values built with the DSL' do
      conflicting.do_update { set(user_id: user_id + excluded[:user_id]) }.insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(3)
    end

    it 'updates rows matching the where condition' do
      conflicting
        .do_update { set(user_id: excluded[:user_id]).where(user_id > excluded[:user_id]) }
        .insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'skips rows not matching the where condition' do
      conflicting
        .do_update { set(user_id: excluded[:user_id]).where(user_id < excluded[:user_id]) }
        .insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(2)
    end

    it 'accepts hash conditions in where' do
      conflicting
        .do_update { set(user_id: excluded[:user_id]).where(user_id: 2) }
        .insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'merges listed columns with the block' do
      conflicting.do_update(:user_id) { where(user_id: 2) }.insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'lets a later set win' do
      conflicting
        .do_update { set(user_id: nil).set(user_id: excluded[:user_id]) }
        .insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'merges assignments of chained calls' do
      conflicting.do_update(title: 'Renamed').do_update(:user_id).insert(user_id: 1, title: "Joe's task")

      expect(joes_task).to eql(id: 1, user_id: 1, title: 'Renamed')
    end

    it 'lets a later call win for the same column' do
      conflicting.do_update(user_id: nil).do_update(:user_id).insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(1)
    end

    it 'keeps previous assignments when a later call only adds a condition' do
      conflicting
        .do_update(title: 'Renamed')
        .do_update { where(user_id: 2) }
        .insert(user_id: 1, title: "Joe's task")

      expect(joes_task).to eql(id: 1, user_id: 2, title: 'Renamed')
    end

    it 'joins conditions of chained calls with AND' do
      conflicting
        .do_update(:user_id) { where(user_id: 2) }
        .do_update { where(user_id < excluded[:user_id]) }
        .insert(user_id: 1, title: "Joe's task")

      expect(joes_task[:user_id]).to be(2)
    end

    it 'handles conflicts in multi_insert' do
      conflicting.do_update(:user_id).multi_insert(
        [{ user_id: 1, title: "Joe's task" }, { user_id: 2, title: "Jane's task" }, { user_id: 1, title: 'New task' }]
      )

      expect(relation.by_pk(1).one[:user_id]).to be(1)
      expect(relation.by_pk(2).one[:user_id]).to be(2)
      expect(relation.where(title: 'New task').one).to include(user_id: 1)
    end

    it 'raises when the block returns neither set nor a hash' do
      expect {
        conflicting.do_update { user_id }
      }.to raise_error(ArgumentError, /set/)
    end
  end
end
