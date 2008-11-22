require File.dirname(__FILE__) + "/test_helper"
require 'adhearsion/cli'

module AhnCommandSpecHelper
  def simulate_args(*args)
    ARGV.clear
    ARGV.concat args
  end
  
  def capture_stdout(&block)
    old = $stdout
    $stdout = io = StringIO.new
    yield
  ensure
    $stdout = old
    return io.string
  end
  
  def new_tmp_dir(filename=String.random)
    File.join Dir.tmpdir, filename
  end
  
  
end

context 'The Ahn Command helper' do
  
  include AhnCommandSpecHelper
  
  test "args are simulated properly" do
    before = ARGV.clone
    simulate_args "create", "/tmp/blah"
    ARGV.should.not.equal before
  end
  
  test "STDOUT should be captured" do
    capture_stdout do
      puts "wee"
    end.should.equal "wee\n"
  end
  
end

context "A simulated use of the 'ahn' command" do
  
  include AhnCommandSpecHelper
  
  test "USAGE is defined" do
    assert Adhearsion::CLI::AhnCommand.const_defined?('USAGE')
  end
  
  test "arguments to 'create' are executed properly properly" do
    some_path = "/path/somewhere"
    simulate_args "create", some_path
    flexmock(Adhearsion::CLI::AhnCommand::CommandHandler).should_receive(:create).once.with(some_path, :default)
    capture_stdout { Adhearsion::CLI::AhnCommand.execute! }
  end
  
  test "arguments to 'start' are executed properly properly" do
    some_path = "/tmp/blargh"
    simulate_args "start", some_path
    flexmock(Adhearsion::CLI::AhnCommand::CommandHandler).should_receive(:start).once.with(some_path, false, nil)
    Adhearsion::CLI::AhnCommand.execute!
  end
  
  test "should execute arguments to 'start' for daemonizing properly" do
    somewhere = "/tmp/blarghh"
    simulate_args "start", 'daemon', somewhere
    flexmock(Adhearsion::CLI::AhnCommand::CommandHandler).should_receive(:start).once.with(somewhere, true, nil)
    Adhearsion::CLI::AhnCommand.execute!
  end
  
  test 'parse_arguments should recognize start with daemon properly' do
    path = '/path/to/somesuch'
    arguments = ["start", 'daemon', path]
    Adhearsion::CLI::AhnCommand.parse_arguments(arguments).should == [:start, path, true, nil]
  end
  
  test 'should recognize start with daemon and pid file properly' do
    project_path  = '/second/star/on/the/right'
    pid_file_path = '/straight/on/til/morning'
    arguments = ["start", "daemon", project_path, "--pid-file=#{pid_file_path}"]
    Adhearsion::CLI::AhnCommand.parse_arguments(arguments).should == [:start, project_path, true, pid_file_path]
  end
  
  test 'parse_arguments should recognize start without daemon properly' do
    path = '/path/to/somewhere'
    arguments = ['start', path]
    Adhearsion::CLI::AhnCommand.parse_arguments(arguments).should == [:start, path, false, nil]
  end
  
  test "if no path is provided, running Ahn command blows up" do
    flexmock(Adhearsion::CLI::AhnCommand).should_receive(:fail_and_print_usage).once.and_return
    Adhearsion::CLI::AhnCommand.parse_arguments(['start'])
  end
  
  test "printing the version" do
    capture_stdout do
      simulate_args 'version'
      Adhearsion::CLI::AhnCommand.execute!
    end.should =~ Regexp.new(Regexp.escape(Adhearsion::VERSION::STRING))
  end
  
  test "printing the help" do
    capture_stdout do
      simulate_args 'help'
      Adhearsion::CLI::AhnCommand.execute!
    end.should =~ Regexp.new(Regexp.escape(Adhearsion::CLI::AhnCommand::USAGE))
  end
  
  test "reacting to unrecognized commands" do
    simulate_args "alpha", "beta"
    flexmock(Adhearsion::CLI::AhnCommand).should_receive(:fail_and_print_usage).once.and_return
    Adhearsion::CLI::AhnCommand.execute!
  end
  
  test "giving a path that doesn't contain a project raises an exception" do
    the_following_code {
      simulate_args "start", "/asjdfas/sndjfabsdfbqwb/qnjwejqbwh"
      Adhearsion::CLI::AhnCommand.execute!
    }.should.raise(Adhearsion::CLI::AhnCommand::CommandHandler::PathInvalid)
  end
  
  test "giving an unrecognized project name raises an exception" do
    the_following_code {
      nonexistent_app_name, nonexistent_path = "a2n8y3gny2", "/tmp/qjweqbwas"
      simulate_args "create:#{nonexistent_app_name}", nonexistent_path
      Adhearsion::CLI::AhnCommand.execute!
    }.should.raise Adhearsion::CLI::AhnCommand::CommandHandler::UnknownProject
  end
end

context 'A real use of the "ahn" command' do
  
  include AhnCommandSpecHelper
  
  test "the 'create' command" do
    the_following_code {
      tmp_path = new_tmp_dir
      simulate_args "create", tmp_path
      RubiGen::Base.default_options.merge! :quiet => true
      capture_stdout { Adhearsion::CLI::AhnCommand.execute! }
      File.exists?(File.join(tmp_path, ".ahnrc")).should.be true
    }.should.not.raise
  end
  
end