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
        allow(logger).to receive(:info)
        allow(logger).to receive(:fatal)
        allow(logger).to receive(:error)
        allow(logger).to receive(:debug)
        allow(logger).to receive(:unknown)

        # So, Object has a private #warn method, so we have to get crafty to stub it.
        # Also, this is dirty as all heck.
        logger.instance_eval do
          def warn(*args)
          end
        end

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

      describe '#status' do
        let(:msg) {'some message'}
        let(:gsubbed) {'gsubbed'}
        let(:result) {shell.status(msg)}

        before(:each) do
          allow(msg).to receive(:gsub).and_return(gsubbed)
        end

        # This example literally cannot come up in ruby-1.8.7, as the `Encoding` module
        # `String#force_encoding` method totally aren't a thing until ruby-1.9.3
        if RUBY_VERSION >= "1.9.3"
          context 'when the message supports forced encoding' do
            before(:each) do
              allow(msg).to receive(:force_encoding)
            end

            it 'forces the encoding to UTF-8' do
              expect(msg).to receive(:force_encoding).with(::Encoding::UTF_8)

              result
            end
          end
        end

        it 'puts the status prefix at the beginning of each line in the message' do
          expect(msg).
            to receive(:gsub).
            with(described_class::BOL, described_class::STATUS_PREFIX).
            and_return(gsubbed)

          result
        end

        it 'logs the modified message as an info line' do
          expect(logger).to receive(:info).with(gsubbed)

          result
        end
      end

      describe '#substatus' do
        let(:msg) {'some message'}
        let(:gsubbed) {'gsubbed'}
        let(:result) {shell.substatus(msg)}

        before(:each) do
          allow(msg).to receive(:gsub).and_return(gsubbed)
        end

        it 'adds the substatus prefix to the beginning of each line in the message' do
          expect(msg).
            to receive(:gsub).
            with(described_class::BOL, described_class::SUBSTATUS_PREFIX).
            and_return(gsubbed)

          result
        end

        it 'logs the modified message as a debug line' do
          expect(logger).to receive(:debug).with(gsubbed)

          result
        end
      end

      describe '#fatal' do
        let(:msg) {'finish him!'}
        let(:result) {shell.fatal(msg)}

        it 'forwards the call to the logger after decorating the message' do
          expect(logger).to receive(:fatal).with("FATAL: #{msg}")

          result
        end
      end

      describe '#error' do
        let(:msg) {'you do not know the way'}
        let(:result) {shell.error(msg)}

        it 'forwards the call to the logger after decorating the message' do
          expect(logger).to receive(:error).with("ERROR: #{msg}")

          result
        end
      end

      describe '#warning' do
        let(:msg) {'she knew that her life had passed her by'}
        let(:result) {shell.warning(msg)}

        it 'forwards the call to the logger after decorating the message' do
          expect(logger).to receive(:warn).with("WARNING: #{msg}")

          result
        end
      end

      describe '#warn' do
        let(:msg) {'watch out for that tree'}
        let(:result) {shell.warn(msg)}

        it 'forwards the call to the logger after decorating the message' do
          expect(logger).to receive(:warn).with("WARNING: #{msg}")

          result
        end
      end

      describe '#notice' do
        let(:msg) {'of intent'}
        let(:result) {shell.notice(msg)}

        it 'warns unmodified via the logger' do
          expect(logger).to receive(:warn).with(msg)

          result
        end
      end

      describe '#info' do
        let(:msg) {'rmation'}
        let(:result) {shell.info(msg)}

        it 'forwards the call to the logger unmodified' do
          expect(logger).to receive(:info).with(msg)

          result
        end
      end

      describe '#debug' do
        let(:msg) {'a buggy bug on a bug made of bugs'}
        let(:result) {shell.debug(msg)}

        it 'forwards the call to the logger unmodified' do
          expect(logger).to receive(:debug).with(msg)

          result
        end
      end

      describe '#unknown' do
        let(:msg) {'soldier'}
        let(:result) {shell.unknown(msg)}

        it 'forwards the call to the logger unmodified' do
          expect(logger).to receive(:unknown).with(msg)

          result
        end
      end

      describe '#command_show' do
        let(:cmd) {'some command'}
        let(:continued) {'continued command'}
        let(:prefixed) {'prefixed continued command'}
        let(:result) {shell.command_show(cmd)}

        before(:each) do
          allow(cmd).to receive(:gsub).and_return(continued)
          allow(continued).to receive(:sub).and_return(prefixed)
        end

        it 'adds the command continue decoration to each line of the message' do
          expect(cmd).
            to receive(:gsub).
            with(described_class::BOL, described_class::CMD_CONTINUE).
            and_return(continued)

          result
        end

        it 'replaces the first command continue decoration with a command prefix' do
          expect(continued).
            to receive(:sub).
            with(described_class::CMD_CONTINUE, described_class::CMD_PREFIX).
            and_return(prefixed)

          result
        end

        it 'logs the decorated message as a debug line via the logger' do
          expect(logger).to receive(:debug).with(prefixed)

          result
        end
      end

      describe '#comand_out' do
        let(:msg) {'some message'}
        let(:indented) {'indented message'}
        let(:result) {shell.command_out(msg)}

        before(:each) do
          allow(msg).to receive(:gsub).and_return(indented)
        end

        it 'indents each line of the message' do
          expect(msg).
            to receive(:gsub).
            with(described_class::BOL, described_class::CMD_INDENT).
            and_return(indented)

          result
        end

        it 'logs the indented message as a debug line via the logger' do
          expect(logger).to receive(:debug).with(indented)

          result
        end
      end

      describe '#command_err' do
        let(:msg) {'some message'}
        let(:indented) {'indented message'}
        let(:result) {shell.command_err(msg)}

        before(:each) do
          allow(msg).to receive(:gsub).and_return(indented)
        end

        it 'indents each line of the message' do
          expect(msg).
            to receive(:gsub).
            with(described_class::BOL, described_class::CMD_INDENT).
            and_return(indented)

          result
        end

        it 'logs the indented message as an unknown line via the logger' do
          expect(logger).to receive(:unknown).with(indented)

          result
        end
      end

      describe '#logged_system' do
        let(:cmd) {Object.new}
        let(:spawn_result) {Object.new}
        let(:result) {shell.logged_system(cmd)}

        it 'spawns the command, passing the shell to the spawner' do
          expect(EY::Serverside::Spawner).
            to receive(:run).
            with(cmd, shell, nil).
            and_return(spawn_result)

          expect(result).to eql(spawn_result)
        end

        context 'when a server is passed in' do
          let(:server) {Object.new}
          let(:result) {shell.logged_system(cmd, server)}

          it 'passes the server along as well' do
            expect(EY::Serverside::Spawner).
              to receive(:run).
              with(cmd, shell, server).
              and_return(spawn_result)

            expect(result).to eql(spawn_result)
          end
        end
      end
    end

  end
end
