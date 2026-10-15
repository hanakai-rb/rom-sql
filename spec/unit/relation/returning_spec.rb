# frozen_string_literal: true

RSpec.describe ROM::Relation, '#returning' do
  subject(:relation) { relations[:tasks] }

  include_context 'users and tasks'

  # tasks are seeded with explicit ids
  seed do |example|
    conn.run("SELECT setval('tasks_id_seq', (SELECT max(id) FROM tasks))") if postgres?(example)
  end

  with_adapters(:postgres, :sqlite) do
    it 'returns the listed columns of an inserted row' do
      expect(relation.returning(:title).insert(user_id: 1, title: 'New task')).to eql([{ title: 'New task' }])
    end

    it 'accepts attributes' do
      expect(relation.returning(relation[:title]).insert(user_id: 1, title: 'New task'))
        .to eql([{ title: 'New task' }])
    end

    it 'returns every column without arguments' do
      expect(relation.returning.insert(user_id: 1, title: 'New task'))
        .to match([{ id: Integer, user_id: 1, title: 'New task' }])
    end

    it 'returns the rows written by multi_insert' do
      expect(
        relation.returning(:title).multi_insert([{ user_id: 1, title: 'One' }, { user_id: 2, title: 'Two' }])
      ).to eql([{ title: 'One' }, { title: 'Two' }])
    end

    it 'returns the rows changed by update' do
      expect(relation.by_pk(1).returning(:title).update(title: 'Renamed')).to eql([{ title: 'Renamed' }])
    end

    it 'returns the rows removed by delete' do
      expect(relation.by_pk(1).returning(:id).delete).to eql([{ id: 1 }])
    end

    it 'leaves reading from the relation unaffected' do
      expect(relation.returning(:title).by_pk(1).one).to include(id: 1, title: "Joe's task")
    end

    context 'with conflict handling' do
      setup_tables do
        conn.add_index :tasks, :title, unique: true
      end

      it 'returns only the rows an upsert wrote' do
        tuples = [{ user_id: 1, title: "Joe's task" }, { user_id: 1, title: 'New task' }]

        expect(relation.on_conflict(:title).returning(:title).multi_insert(tuples)).to eql([{ title: 'New task' }])
      end

      it 'returns updated rows matching the condition' do
        result = relation
          .returning(:id, :user_id)
          .on_conflict(:title)
          .do_update(:user_id) { where(user_id: 2) }
          .multi_insert([{ user_id: 1, title: "Joe's task" }, { user_id: 1, title: "Jane's task" }])

        expect(result).to eql([{ id: 1, user_id: 1 }])
      end
    end
  end

  with_adapters(:mysql) do
    it 'raises an error when the database does not support RETURNING' do
      expect { relation.returning(:id) }
        .to raise_error(ROM::SQL::UnsupportedFeatureError, /RETURNING is not supported by mysql/)
    end
  end
end
