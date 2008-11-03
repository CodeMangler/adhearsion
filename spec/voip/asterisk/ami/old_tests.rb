=begin
context "Connecting via AMI" do
  test "should raise an exception if the password was invalid" do
    host, port = "localhost", 5038
    ami = Adhearsion::VoIP::Asterisk::AMI.new "admin", "bad_password", "localhost", :port => port
  
    ami_server = AmiServer.new
    flexmock(TCPSocket).should_receive(:new).once.with(host, port).and_return(ami_server)
    flexmock(IO).should_receive(:select).at_least.once.with([ami_server], nil, nil, 1.0).and_return(true)

    the_following_code do
      ami.connect!
    end.should.raise Adhearsion::VoIP::Asterisk::AMI::AuthenticationFailedException
    ami.disconnect!
  end
  
  test "should discover its own permissions and make them available as connection attributes"
  
  test "should find the Asterisk version when connecting" do
    host, port = "localhost", 5038
    ami = Adhearsion::VoIP::Asterisk::AMI.new "admin", "password", "localhost", :port => port
  
    ami_server = AmiServer.new
    flexmock(TCPSocket).should_receive(:new).once.with(host, port).and_return(ami_server)
    flexmock(IO).should_receive(:select).at_least.once.with([ami_server], nil, nil, 1.0).and_return(true)

    ami.connect!
    ami.version.should == "1.0"
    ami.disconnect!
  end
end

context "The AMI command interface" do
  
  before do
    host, port = "localhost", 5038
    @ami = Adhearsion::VoIP::Asterisk::AMI.new "admin", "password", host, :port => port, :events => false

    ami_server = AmiServer.new
    flexmock(TCPSocket).should_receive(:new).once.with(host, port).and_return(ami_server)
    flexmock(IO).should_receive(:select).at_least.once.with([ami_server], nil, nil, 1.0).and_return(true)

    @ami.connect!
  end
  
  after do
    @ami.disconnect!
  end
  
  test "should respond to an immediate command" do
    resp = @ami.queues
    resp[0][:raw].should.be.a.kind_of String
  end

  test "should respond to a follows command" do
    resp = @ami.command :Command => "show channels"
    resp[0][:raw].should.be.a.kind_of String
  end

  test "should respond to a DBGet for a non-existent key with an exception" do
    the_following_code do
      resp = @ami.dbget :Family => "none", :Key => "somekey"
    end.should.raise Adhearsion::VoIP::Asterisk::AMI::ActionError
  end
  
  test "should respond to a DBGet for a key with an event" do
    resp = @ami.dbput :Family => "none", :Key => "somekey", :Val => 5
    resp = @ami.dbget :Family => "none", :Key => "somekey"
    resp[0]['Val'].should == "5"
  end
  
  test "should respond to a command that generates follows event(s)" do
    resp = @ami.queuestatus
    resp[0]['Queue'].should == "default"
  end
  
  test "should show usage for an improper follows command" do
    resp = @ami.command :Command => "meetme list"
    resp[0][:raw].should.be.a.kind_of String
  end
  
  test "should respond to a synchronous originate"
  test "should respond to an asynchronous originate"

  test "should define events() as a private method to prevent turning events on or off" do
    @ami.private_methods.include?("events").should.equal true
  end
  
  test "should raise an exception when Asterisk doesn't recognize a command" do
    the_following_code {
      @ami.this_command_does_not_exist_kthx
    }.should.raise Adhearsion::VoIP::Asterisk::AMI::ActionError
    
  end
  
end

context 'AMI#originate' do
  include AmiCommandTestHelper
  test "should pass the arguments to execute_ami_command! with the options given" do
    ami     = new_ami_instance
    options = { :channel => "ohai_lolz", :application => "Echo" }
    flexmock(ami).should_receive(:execute_ami_command!).with(:originate, options).once
    ami.originate options
  end
  
  test "should rename the :caller_id Hash key to :callerid" do
    ami, caller_id = new_ami_instance, "Jay"
    options = { :channel => "ohai_lolz", :application => "Echo"}
    flexmock(ami).should_receive(:execute_ami_command!).with(:originate, options.merge(:callerid => caller_id)).once
    ami.originate options.merge(:caller_id => caller_id)
  end
  
end

context 'AMI#call_and_exec' do
  include AmiCommandTestHelper
  test "should execute originate properly with the minimum arguments" do
    number, app = "12224446666", "Echo"
    
    ami = flexmock new_ami_instance
    ami.should_receive(:originate).once.with(:channel => number, :application => app).and_return true
    ami.call_and_exec number, app
  end
  
end

context 'AMI#introduce' do
  
  include AmiCommandTestHelper
  
  test "should execute origiante properly (when :caller_id and :options aren't specified)" do
    caller, callee, caller_id = "SIP/12224446666@trunk", "SIP/12224447777@trunk", "Jay Phillips"
    
    correct_args = {:application => "Dial", :channel => caller, :data => callee, :caller_id => "Jay"}
    ami = flexmock new_ami_instance
    ami.should_receive(:originate).once.with(correct_args).and_return(true)
    ami.introduce caller, callee, :caller_id => "Jay"
  end
  
end

context "The manager proxy" do
  before do
    host, port = "localhost", 5038
    @ami = Adhearsion::VoIP::Asterisk::AMI.new "admin", "password", "localhost", :port => port, :events => false

    ami_server = AmiServer.new
    flexmock(TCPSocket).should_receive(:new).once.with(host, port).and_return(ami_server)
    flexmock(IO).should_receive(:select).at_least.once.with([ami_server], nil, nil, 1.0).and_return(true)

    @ami.connect!
    @door = DRb.start_service "druby://127.0.0.1:9050", Adhearsion::DrbDoor.instance
  end
  
  test "should accept a command" do
    client = DRbObject.new nil, DRb.uri
    client.proxy.ping
  end

  after do
    DRb.stop_service
    @ami.disconnect!
  end
end

context "The command-sending interface" do
  test "should raise an exception if permission was denied"
  test "should allow variables to be specified as a Hash"
end

context "Sent arbitrary AMI commands" do
  
  test "should allow a convenient way of parsing by event name"
  test "should return Hash arguments"
  
  test "should recognize its subclasses"
  test "should send events to all of its subclasses"
  test "should catch action names with method_missing() and format them properly"

  test "should raise an exception if permission was denied"
end

context "AMI Packets" do
  test "A Packet should not be an error" do
    Adhearsion::VoIP::Asterisk::AMI::Packet.new.error?.should.be false
  end
  test "An ErrorPacket should be an error" do
    Adhearsion::VoIP::Asterisk::AMI::ErrorPacket.new.error?.should.be true
  end
end

BEGIN {
module AmiCommandTestHelper
  def new_ami_instance
    # TODO. mock everything out here
    returning Adhearsion::VoIP::Asterisk::AMI.new("user","pass") do |ami|
      flexmock(ami).should_receive(:connect!).and_return(true)
    end
  end
  
end
}
=end