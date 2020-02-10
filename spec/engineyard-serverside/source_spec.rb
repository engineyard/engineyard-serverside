require 'spec_helper'

require 'engineyard-serverside/source'

module EY
  module Serverside

    describe Source do
      let(:source) {described_class.new(opts)}

      before(:each) do
        described_class.instance_eval do
          @required_opts = nil
        end
      end

      after(:each) do
        described_class.instance_eval do
          @required_opts = nil
        end
      end

      describe '.new' do
        let(:shell) {Object.new}

        let(:result) {described_class.new(shell)}

        it 'sets the shell to that provided' do
          expect(result.shell).to eql(shell)
        end

        context 'when no options are provided' do
          it 'sets the options to an empty hash' do
            expect(result.opts).to eql({})
          end
        end

        context 'when there are required options' do
          let(:opts) {{}}
          let(:result) {described_class.new(shell, opts)}

          before(:each) do
            described_class.instance_eval do
              @required_opts = [:foo, :bar]
            end
          end

          context 'that are missing' do
            it 'raises an argument error' do
              expect {result}.to raise_error(ArgumentError)
            end
          end

          context 'that are satisfied' do
            let(:opts) {{:foo => 'foo', :bar => 'bar'}}

            it 'does not raise an error' do
              expect {result}.not_to raise_error
            end
          end
        end

        context 'when options are provided' do
          let(:opts) {{}}
          let(:result) {described_class.new(shell, opts)}

          context 'and a ref is provided' do
            let(:ref) {1234}
            let(:opts) {{:ref => ref}}

            it 'stringifies the provided ref and saves it' do
              expect(result.ref).to eql(ref.to_s)
            end
          end

          context 'and no ref is provided' do
            it 'saves a blank string' do
              expect(result.ref).to eql('')
            end
          end

          context 'and a uri is provided' do
            let(:uri) {'http://example.com'}
            let(:opts) {{:uri => uri}}

            it 'saves the provided uri' do
              expect(result.uri).to eql(uri)
            end
          end

          context 'and no uri is provided' do
            it 'saves a nil uri' do
              expect(result.uri).to be_nil
            end
          end

          context 'and a repository cache is provided' do
            let(:repository_cache) {'/path/to/repo/cache'}
            let(:opts) {{:repository_cache => repository_cache}}

            it 'saves the provided repository_cache as a source_cache path' do
              expect(result.source_cache).to eql(Pathname.new(repository_cache))
            end
          end

          context 'and no repository cache is provided' do
            it 'saves a nil source_cache' do
              expect(result.source_cache).to be_nil
            end
          end
        end
      end

      describe '.required_opts' do
        context 'without arguments' do
          let(:result) {described_class.required_opts}

          context 'when there are required options' do
            before(:each) do
              described_class.instance_eval do
                @required_opts = [:foo, :bar]
              end
            end

            it 'is the required option array' do
              expect(result).to eql([:foo, :bar])
            end
          end

          context 'when there are no required options' do
            it 'is nil' do
              expect(result).to be_nil
            end
          end
        end
      end

      describe '.require_opts' do
        let(:result) {described_class.require_opts(:foo, :bar)}

        context 'when there are no required options' do
          it 'sets the required opts to those provided' do
            expect(described_class.required_opts).to be_nil

            result

            expect(described_class.required_opts).to eql([:foo, :bar])
          end
        end

        context 'when there are already required options' do
          before(:each) do
            described_class.instance_eval do
              @required_opts = [:bob]
            end
          end

          it 'adds the provided names to the required opts' do
            expect(described_class.required_opts).to eql([:bob])

            result

            expect(described_class.required_opts).to eql([:bob, :foo, :bar])
          end
        end
      end

    end

  end
end
