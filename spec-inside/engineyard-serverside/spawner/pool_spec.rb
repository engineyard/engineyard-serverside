require 'spec_helper'

require 'engineyard-serverside/spawner/pool'

class StepChild
end

module EY
  module Serverside
    module Spawner
      describe Pool do
        let(:cmd) {'true'}
        let(:shell) {Object.new}
        let(:child_class) {EY::Serverside::Spawner::Child}
        let(:spawner) {described_class.new}

        before(:each) do
          allow(shell).to receive(:command_show)
          allow(shell).to receive(:command_out)
        end

        it 'has a hard poll period for child processes' do
          expect(described_class::POLL_PERIOD).to eql(0.5)
        end

        describe '#add' do
          let(:child) {StepChild.new}
          let(:add) {spawner.add(cmd, shell)}

          it 'adds a child process to the spawner' do
            expect(child_class).to receive(:new).and_return(child)

            expect(spawner.instance_eval {children}).not_to include(child)

            add

            expect(spawner.instance_eval {children}).to include(child)
          end

          context 'when no server is provided' do
            it 'adds a serverless child' do
              expect(child_class).
                to receive(:new).
                with(cmd, shell, nil).
                and_return(child)

              add

              expect(spawner.instance_eval {children}).to include(child)
            end
          end

          context 'when a server is provided' do
            let(:server) {Object.new}
            let(:add) {spawner.add(cmd, shell, server)}

            it 'adds a child with a server' do
              expect(child_class).
                to receive(:new).
                with(cmd, shell, server).
                and_return(child)

              add

              expect(spawner.instance_eval {children}).to include(child)
            end
          end
        end

        describe '#run' do
          let(:cmd1) {'true'}
          let(:cmd2) {'echo "the dolphin"'}

          let(:run) {spawner.run}

          it 'is an array' do
            expect(run).to be_a(Array)
          end

          context 'with no child processes' do
            it 'is empty' do
              expect(run).to be_empty
            end
          end

          context 'with child processes' do
            let(:children) {spawner.instance_eval {children}}

            before(:each) do
              spawner.add(cmd1, shell)
              spawner.add(cmd2, shell)
            end

            it 'spawns all child processes' do
              children.each do |child|
                expect(child).to receive(:spawn).and_call_original
              end

              run
            end

            it 'waits for child processes to finish' do
              expect(spawner).to receive(:wait_for_children).and_call_original

              run
            end

            it 'contains the results of all child processes' do
              expect(children.length > 0).to eql(true)

              expect(run.length).to eql(children.length)

              run.each do |member|
                expect(member).to be_a(EY::Serverside::Spawner::Result)
                expect([cmd1, cmd2]).to include(member.command)
              end
            end

            context 'when waiting for the pid fails' do
              context 'because waitpid2 cannot find the process' do
                let(:pid) {-1}
                let(:status) {"bad pid"}

                before(:each) do
                  allow(Process).
                    to receive(:waitpid2).
                    with(-1, Process::WNOHANG).
                    and_return([pid, status])
                end

                it 'raises a WaitError regarding the bad pid' do
                  expect {run}.
                    to raise_error(EY::Serverside::Spawner::WaitError, /Fatal error encountered while waiting for a child process to exit/)
                end
              end

              context 'because waitpid2 returns an unknown pid' do
                let(:pid) {-2}
                let(:status) {'unknown pid'}

                before(:each) do
                  allow(Process).
                    to receive(:waitpid2).
                    with(-1, Process::WNOHANG).
                    and_return([pid, status])
                end

                it 'raises a WaitError regarding the unknown pid' do
                  expect {run}.
                    to raise_error(EY::Serverside::Spawner::WaitError, /Unknown pid returned from waitpid2/)
                end
              end
            end
          end
        end


      end
    end
  end
end
