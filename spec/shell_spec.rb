require 'spec_helper'
require 'tempfile'
require 'timecop'

describe EY::Serverside::Shell do
  it "has a timestamp before each line" do
    time1 = Time.local(2008, 9, 1, 12, 0, 0)
    time2 = Time.local(2008, 9, 1, 12, 3, 5)
    time3 = Time.local(2008, 9, 1, 12, 10, 25)

    @output = StringIO.new
    @shell = EY::Serverside::Shell.new(:verbose => true, :stdout => @output, :stderr => @output, :log_path => Pathname.new(Dir.tmpdir).join("engineyard-serverside-#{Time.now.to_i}-${$$}.log"), :start_time => time1)

    Timecop.freeze(time1) do
      @shell.debug('test1')
      @shell.warning('test2')
    end
    Timecop.freeze(time2) do
      @shell.status('STATUS')
      @shell.debug("test11\ntest12\ntest13")
      @shell.warning("test21\ntest22\ntest23")
    end
    Timecop.freeze(time3) do
      @shell.substatus("test31\ntest32\ntest33")
    end

    tstp_1 = "+    00s "
    tstp_2 = "+ 3m 05s "
    tstp_3 = "+10m 25s "
    notstp = "         "
    @output.rewind
    @output.read.should == <<-OUTPUT
#{notstp} test1
#{tstp_1} !> WARNING: test2

\e[1m#{tstp_2} ~> STATUS
\e[0m#{notstp} test11
#{notstp} test12
#{notstp} test13
#{tstp_2} !> WARNING: test21
#{tstp_2} !> test22
#{tstp_2} !> test23
#{notstp}  ~ test31
#{notstp}  ~ test32
#{notstp}  ~ test33
    OUTPUT
  end
end
