# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ROM::SQL::UpsertDSL, :sqlite, helpers: true do
  include_context 'database setup'

  subject(:dsl) do
    ROM::SQL::UpsertDSL.new(schema)
  end

  let(:schema) do
    define_schema(
      :users,
      id: ROM::SQL::Types::Serial,
      name: ROM::SQL::Types::String,
      updated_at: ROM::SQL::Types::Time
    )
  end

  let(:ds) do
    conn[:users]
  end

  describe '#excluded' do
    it 'qualifies attributes with the excluded table' do
      expect(ds.literal(dsl.excluded[:name])).to eql('`excluded`.`name`')
    end
  end

  describe '#call' do
    it 'returns assignments from a hash' do
      set, where = dsl.call { { name: excluded[:name] } }

      expect(ds.literal(set[:name])).to eql('`excluded`.`name`')
      expect(where).to be_nil
    end

    it 'returns assignments from set' do
      set, where = dsl.call { set(name: excluded[:name], updated_at: excluded[:updated_at]) }

      expect(set.keys).to eql(%i[name updated_at])
      expect(ds.literal(set[:name])).to eql('`excluded`.`name`')
      expect(where).to be_nil
    end

    it 'returns the condition from where' do
      _, where = dsl.call { set(name: excluded[:name]).where(updated_at < excluded[:updated_at]) }

      expect(ds.literal(where)).to eql('(`updated_at` < `excluded`.`updated_at`)')
    end

    it 'allows where before set' do
      set, where = dsl.call { where(updated_at < excluded[:updated_at]).set(name: excluded[:name]) }

      expect(set.keys).to eql(%i[name])
      expect(ds.literal(where)).to eql('(`updated_at` < `excluded`.`updated_at`)')
    end

    it 'qualifies hash conditions with the table' do
      _, where = dsl.call { set(name: excluded[:name]).where(name: 'Jane') }

      expect(ds.literal(where)).to eql("(`users`.`name` = 'Jane')")
    end

    it 'lets a later set win' do
      set, = dsl.call { set(name: 'Jane').set(name: excluded[:name]) }

      expect(ds.literal(set[:name])).to eql('`excluded`.`name`')
    end

    it 'resolves functions with the virtual row' do
      set, = dsl.call { set(name: coalesce(name, excluded[:name])) }

      expect(ds.literal(set[:name])).to eql('coalesce(`name`, `excluded`.`name`)')
    end

    it 'raises when the block returns neither set nor a hash' do
      expect { dsl.call { name } }.to raise_error(ArgumentError, /set/)
    end
  end
end
