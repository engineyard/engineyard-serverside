require 'spec_helper'
require 'timecop'

require 'engineyard-serverside/shell'

module EY
  module Serverside

    describe Shell do
      let(:logger) {Object.new}
      let(:start_time) {nil}
      let(:verbose) {nil}
      let(:stdout) {nil}
      let(:stderr) {nil}
      let(:log_path) {'fake.log'}
      let(:options) {
        {
          :start_time => start_time,
          :verbose => verbose,
          :stdout => stdout,
          :stderr => stderr,
          :log_path => log_path
        }
      }

      let(:now_is_the_time) {Time.local(2020, 02, 14, 13, 0, 0)}
      let(:log_pathname) {Object.new}
      let(:logger) {Object.new}
      let(:formatter) {Object.new}

      let(:shell) {described_class.new(options)}

      before(:each) do
        # STub out the logfile to keep from leaving file system artifacts
        allow(Pathname).to receive(:new).with(log_path).and_return(log_pathname)
        allow(log_pathname).to receive(:exist?).and_return(false)
        allow(log_pathname).to receive(:unlink)
        allow(log_pathname).to receive(:to_s).and_return(log_path)

        # Stub out the actual logger for the same reason
        allow(Logger).to receive(:new).and_return(logger)
        allow(logger).to receive(:formatter=)
        allow(logger).to receive(:level=)

        # Let's go ahead and make sure we can predict the time, too.
        Timecop.freeze(now_is_the_time)
      end

      after(:each) do
        Timecop.return
      end

      describe '.new' do
        let(:result) {shell}

        it 'sets the log level to DEBUG' do
          expect(logger).to receive(:level=).with(Logger::DEBUG)

          result
        end

        context 'when a start time is provided' do
          let(:start_time) {now_is_the_time + 3600}

          it 'formats log messages based on that start time' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, start_time, verbose).
              and_call_original

            result
          end
        end

        context 'when no start time is provided' do
          it 'formats log messages based on the current  time' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, now_is_the_time, verbose).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when verbosity is requested' do
          let(:verbose) {true}

          it 'formats log messages verbosely' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, now_is_the_time, true).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when verobisty is disabled' do
          let(:verbose) {false}

          it 'does not use verbose formatting for logs' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, now_is_the_time, false).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when no verbosity preference is provided' do
          it 'does not use verbose formatting for logs' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, now_is_the_time, nil).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when the provided log path exists' do
          before(:each) do
            allow(log_pathname).to receive(:exist?).and_return(true)
          end

          it 'unlinks the log file' do
            expect(log_pathname).to receive(:unlink)

            result
          end
        end

        context 'when the provided log path does not exist' do
          it 'does not unlink the log file' do
            expect(log_pathname).not_to receive(:unlink)

            result
          end
        end

        context 'when stdout is provided' do
          let(:stdout) {Object.new}

          it 'passes the provided stdout to the formatter' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with(stdout, $stderr, now_is_the_time, verbose).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when stdout is not provided' do
          it 'passes the real stdout to the formatter' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, now_is_the_time, verbose).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when stderr is provided' do
          let(:stderr) {Object.new}

          it 'passes the provided stderr to the formatter' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, stderr, now_is_the_time, verbose).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end

        context 'when stderr is not provided' do
          it 'passes the real stderr to the formatter' do
            expect(EY::Serverside::Shell::Formatter).
              to receive(:new).
              with($stdout, $stderr, now_is_the_time, verbose).
              and_return(formatter)

            expect(logger).to receive(:formatter=).with(formatter)

            result
          end
        end
      end

      describe '#logger' do
        let(:result) {shell.logger}

        it 'is the logger created during initilization' do
          expect(result).to eql(logger)
        end
      end

      describe '#start_time' do
        let(:result) {shell.start_time}

        context 'when a start time was provided during initialization' do
          let(:start_time) {now_is_the_time + 7200}

          it 'is the initilized start time' do
            expect(result).to eql(start_time)
          end
        end

        context 'when no start time was provided during initialization' do
          it 'is the current time as of initialization' do
            expect(result).to eql(now_is_the_time)
          end
        end
      end

      describe '#verbose?' do
        let(:result) {shell.verbose?}

        context 'when verbosity was enabled during initialization' do
          let(:verbose) {true}

          it 'is true' do
            expect(result).to be_truthy
          end
        end

        context 'when verbosity was disabled during initialization' do
          let(:verbose) {false}

          it 'is false' do
            expect(result).to be_falsey
          end
        end

        context 'when verbosity was not provided at initialization' do
          it 'is false' do
            expect(result).to be_falsey
          end
        end


      end

      describe '#status'

      describe '#substatus'

      describe '#fatal'

      describe '#error'

      describe '#warning'

      describe '#warn'

      describe '#notice'

      describe '#info'

      describe '#debug'

      describe '#unknown'

      describe '#command_show'

      describe '#comand_out'

      describe '#command_err'

      describe '#logged_system'
    end

  end
end
