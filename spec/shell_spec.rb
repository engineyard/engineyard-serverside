require 'spec_helper'
require 'tempfile'
require 'timecop'

describe EY::Serverside::Shell do
  if "".respond_to?(:force_encoding)
    it "status works for ut8" do
      output = StringIO.new
      shell = EY::Serverside::Shell.new(:verbose => true, :stdout => @output, :stderr => @output, :log_path => tmpdir.join("engineyard-serverside-#{Time.now.to_i}-#{$$}.log"), :start_time => Time.local(2008, 9, 1, 12, 10, 25))
      shell.status("\u2603".force_encoding("binary"))
    end
  end

  it "has a timestamp before each line" do
    time1 = Time.local(2008, 9, 1, 12, 0, 0)
    time2 = Time.local(2008, 9, 1, 12, 3, 5)
    time3 = Time.local(2008, 9, 1, 12, 10, 25)

    @output = StringIO.new
    @shell = EY::Serverside::Shell.new(:verbose => true, :stdout => @output, :stderr => @output, :log_path => tmpdir.join("engineyard-serverside-#{Time.now.to_i}-#{$$}.log"), :start_time => time1)

    Timecop.freeze(time1) do
      @shell.debug('debug')
      @shell.notice('notice')
    end
    Timecop.freeze(time2) do
      @shell.status('STATUS')
      @shell.debug("multi\nline\ndebug")
      @shell.warning("multi\nline\nwarning")
    end
    Timecop.freeze(time3) do
      @shell.substatus("multi\nline\nsubstatus")
    end

    tstp_1 = "+    00s "
    tstp_2 = "+ 3m 05s "
    tstp_3 = "+10m 25s "
    notstp = "         "
    @output.rewind
    @output.read.should == <<-OUTPUT
#{notstp} debug

\e[1m\e[33m#{tstp_1} !> notice
\e[0m
\e[1m\e[37m#{tstp_2} ~> STATUS
\e[0m#{notstp} multi
#{notstp} line
#{notstp} debug

\e[1m\e[33m#{tstp_2} !> WARNING: multi
#{tstp_2} !> line
#{tstp_2} !> warning
\e[0m#{notstp}  ~ multi
#{notstp}  ~ line
#{notstp}  ~ substatus
    OUTPUT
  end
end
