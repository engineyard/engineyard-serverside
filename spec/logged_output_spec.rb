require 'spec_helper'
require 'tempfile'
require 'timecop'

class SampleLogUser
  include EY::Serverside::LoggedOutput
  def initialize
    EY::Serverside::LoggedOutput.logfile = tempfile.path
    EY::Serverside::LoggedOutput.verbose = true
  end

  def starting_time
    @starting_time ||= Time.now
  end

  def tempfile
    @tempfile ||= Tempfile.new('logged_output')
  end
end

describe EY::Serverside::LoggedOutput do
  before do
    EY::Serverside::LoggedOutput.enable_actual_info!
    @log_user = SampleLogUser.new
  end

  after do
    EY::Serverside::LoggedOutput.disable_actual_info!
  end

  it "has a timestamp before each line" do
    time1 = Time.local(2008, 9, 1, 12, 0, 0)
    time2 = Time.local(2008, 9, 1, 12, 3, 5)
    time3 = Time.local(2008, 9, 1, 12, 10, 25)

    Timecop.freeze(time1) do
      @log_user.debug('test1')
      @log_user.warning('test2')
    end
    Timecop.freeze(time2) do
      @log_user.info('test3')

      @log_user.debug("test11\ntest12\ntest13")
      @log_user.warning("test21\ntest22\ntest23")
    end
    Timecop.freeze(time3) do
      @log_user.info("test31\ntest32\ntest33")
    end

    timestamp_1 = "+ 0m 00s "
    timestamp_2 = "+ 3m 05s "
    timestamp_3 = "+10m 25s "
    File.read(@log_user.tempfile.path).should == "#{timestamp_1}test1\n#{timestamp_1}!> WARNING: test2\n\n#{timestamp_2}test3\n#{timestamp_2}test11\n#{timestamp_2}test12\n#{timestamp_2}test13\n#{timestamp_2}!> WARNING: test21\n#{timestamp_2}!> test22\n#{timestamp_2}!> test23\n\n#{timestamp_3}test31\n#{timestamp_3}test32\n#{timestamp_3}test33\n"
  end
end