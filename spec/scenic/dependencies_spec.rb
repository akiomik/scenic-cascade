# frozen_string_literal: true

RSpec.describe Scenic::Dependencies do
  before do
    ActiveRecord::Base.establish_connection(
      adapter: 'postgresql',
      host: 'localhost',
      username: ENV.fetch('POSTGRES_USER'),
      password: ENV.fetch('POSTGRES_PASSWORD'),
      database: ENV.fetch('POSTGRES_DB')
    )
  end

  it 'has a version number' do
    expect(Scenic::Dependencies::VERSION).not_to be_nil
  end

  describe '.reverse_dependent_views_of' do
    subject { described_class.reverse_dependent_views_of(name, recursive: recursive) }

    let(:recursive) { false }
    let(:adapter) { Scenic::Adapters::Postgres.new }

    before do
      adapter.create_materialized_view(
        'view1',
        "SELECT 'foo' AS bar"
      )
      adapter.create_materialized_view(
        'view2',
        'SELECT * FROM view1'
      )
      adapter.create_materialized_view(
        'view3',
        'SELECT * FROM view1 UNION SELECT * FROM view2'
      )
    end

    context 'when the target view does not exist' do
      let(:name) { 'view0' }

      it { is_expected.to eq [] }
    end

    context 'when the target view has no reverse dependencies' do
      let(:name) { 'view3' }

      it { is_expected.to eq [] }
    end

    context 'when the target view has reverse dependencies' do
      let(:name) { 'view2' }

      let(:expected) do
        [{
          'dependee' => 'view2',
          'depender' => 'view3'
        }]
      end

      it { is_expected.to eq expected }
    end

    context 'when the target view has nested reverse dependencies and recursive is false' do
      let(:name) { 'view1' }

      let(:expected) do
        [{
          'dependee' => 'view1',
          'depender' => 'view2'
        }, {
          'dependee' => 'view1',
          'depender' => 'view3'
        }]
      end

      it { is_expected.to eq expected }
    end

    context 'when the target view has nested reverse dependencies and recursive is true' do
      let(:name) { 'view1' }
      let(:recursive) { true }

      let(:expected) do
        [{
          'dependee' => 'view1',
          'depender' => 'view2'
        }, {
          'dependee' => 'view2',
          'depender' => 'view3'
        }, {
          'dependee' => 'view1',
          'depender' => 'view3'
        }]
      end

      it { is_expected.to eq expected }
    end
  end
end
