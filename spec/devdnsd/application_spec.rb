# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe DevDNSd::Application do
  before(:each) do
    DevDNSd::Logger.stub(:default_file).and_return("/dev/null")
  end

  let(:log_file) { "/tmp/devdnsd-test-log-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:application){ DevDNSd::Application.instance({:log_file => log_file}, {}, {}, true) }
  let(:executable) { ::Pathname.new(::File.dirname((__FILE__))) + "../../bin/devdnsd" }
  let(:sample_config) { ::Pathname.new(::File.dirname((__FILE__))) + "../../config/devdnsd_config.sample" }
  let(:resolver_path) { "/tmp/devdnsd-test-resolver-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:launch_agent_path) { "/tmp/devdnsd-test-agent-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  describe "#initialize" do
    it("should setup the logger") do application.logger.should_not be_nil end
    it("should setup the configuration") do application.config.should_not be_nil end

    it("should abort with an invalid configuration") do
      path = "/tmp/devdnsd-test-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}"
      file = ::File.new(path, "w")
      file.write("config.port = ")
      file.close

      expect { DevDNSd::Application.new({:config => file.path, :log_file => log_file}) }.to raise_error(::SystemExit)
      ::File.unlink(path)
    end
  end

  describe ".run" do
    it "should run the server" do
      application.should_receive(:perform_server)
      DevDNSd::Application.run
    end
  end

  describe ".quit" do
    it "should quit the application" do
      ::EventMachine.should_receive(:stop)
      DevDNSd::Application.quit
    end
  end

  describe "#perform_server" do
    let(:application){ DevDNSd::Application.instance({:log_file => log_file, :config => sample_config}, {}, {}, true) }

    before(:each) do
      DevDNSd::Logger.stub(:default_file).and_return($stdout)

      class DevDNSd::Application
        def on_start
          Thread.main[:resolver].wakeup if Thread.main[:resolver].try(:alive?)
        end
      end
    end

    def test_resolve(host = "match_1.dev", type = "ANY", nameserver = "127.0.0.1", port = 7771, logger = nil)
      host ||= "match.dev"

      Thread.current[:resolver] = Thread.start {
        Thread.stop
        Thread.main[:result] = devdnsd_resolv(host, type, nameserver, port, logger)
      }

      Thread.current[:server] = Thread.start {
        sleep(0.1)

        if block_given? then
          yield
        else
          application.perform_server
        end
      }

      Thread.current[:resolver].join
      Thread.kill(Thread.current[:server])
      Thread.main[:running] = false
      Thread.main[:result]
    end

    it "should run the server" do
      RubyDNS.should_receive(:run_server)
      application.perform_server
    end

    it "should stop the server" do
      application.should_receive(:on_stop)

      Thread.new {
        sleep(1)
        application.class.quit
      }

      application.perform_server
    end

    it "should iterate the rules" do
      test_resolve do
        application.config.rules.should_receive(:each).at_least(1)
        application.perform_server
      end
    end

    it "should call process_rule" do
      test_resolve do
        application.should_receive(:process_rule).at_least(1)
        application.perform_server
      end
    end

    it "should complain about wrong rules" do
      test_resolve do
        application.stub(:process_rule).and_raise(::Exception)
        expect { application.perform_server }.to raise_exception
      end
    end

    describe "should correctly resolve hostnames" do
      it "basing on a exact pattern" do
        test_resolve("match_1.dev").should == ["10.0.1.1", :A]
        test_resolve("match_2.dev").should == ["10.0.2.1", :MX]
        test_resolve("match_3.dev").should == ["10.0.3.1", :A]
        test_resolve("match_4.dev").should == ["10.0.4.1", :CNAME]
      end

      it "basing on a regexp pattern" do
        test_resolve("match_5_11.dev").should == ["10.0.5.11", :A]
        test_resolve("match_5_22.dev").should == ["10.0.5.22", :A]
        test_resolve("match_6_33.dev").should == ["10.0.6.33", :PTR]
        test_resolve("match_6_44.dev").should == ["10.0.6.44", :PTR]
        test_resolve("match_7_55.dev").should == ["10.0.7.55", :A]
        test_resolve("match_7_66.dev").should == ["10.0.7.66", :A]
        test_resolve("match_8_77.dev").should == ["10.0.8.77", :PTR]
        test_resolve("match_8_88.dev").should == ["10.0.8.88", :PTR]
      end

      it "and return multiple or only relevant answsers" do
        test_resolve("match_10.dev").should == [["10.0.10.1", :A], ["10.0.10.2", :MX]]
        test_resolve("match_10.dev", "MX").should == ["10.0.10.2", :MX]
      end

      it "and reject invalid matches (with or without rules)" do
        test_resolve("match_9.dev").should be_nil
        test_resolve("invalid.dev").should be_nil
      end
    end
  end

  describe "#process_rule" do
    class FakeTransaction
      attr_reader :resource_class

      def initialize(cls = Resolv::DNS::Resource::IN::ANY)
        @resource_class = cls
      end

      def respond!(*args)
        true
      end
    end

    let(:application){ DevDNSd::Application.instance({:log_file => log_file, :config => sample_config}, {}, {}, true) }
    let(:transaction){ FakeTransaction.new }

    it "should match a valid string request" do
      rule = application.config.rules[0]
      application.process_rule(rule, rule.resource_class, nil, transaction).should be_true
    end

    it "should match a valid string request with specific type" do
      rule = application.config.rules[1]
      application.process_rule(rule, rule.resource_class, nil, transaction).should be_true
    end

    it "should match a valid string request with a block" do
      rule = application.config.rules[2]
      application.process_rule(rule, rule.resource_class, nil, transaction).should be_true
    end

    it "should match a valid string request with a block" do
      rule = application.config.rules[3]
      application.process_rule(rule, rule.resource_class, nil, transaction).should be_true
    end

    it "should match a valid regexp request" do
      rule = application.config.rules[4]
      mo = rule.match_host("match_5_12.dev")
      application.process_rule(rule, rule.resource_class, mo, transaction).should be_true
    end

    it "should match a valid regexp request with specific type" do
      rule = application.config.rules[5]
      mo = rule.match_host("match_6_34.dev")
      application.process_rule(rule, rule.resource_class, mo, transaction).should be_true
    end

    it "should match a valid regexp request with a block" do
      rule = application.config.rules[6]
      mo = rule.match_host("match_7_56.dev")
      application.process_rule(rule, rule.resource_class, mo, transaction).should be_true
    end

    it "should match a valid regexp request with a block and specific type" do
      rule = application.config.rules[7]
      mo = rule.match_host("match_8_78.dev")
      application.process_rule(rule, rule.resource_class, mo, transaction).should be_true
    end

    it "should return false for a false block" do
      rule = application.config.rules[8]
      application.process_rule(rule, rule.resource_class, nil, transaction).should be_false
    end

    it "should return nil for a nil reply" do
      rule = application.config.rules[0]
      rule.reply = nil
      application.process_rule(rule, rule.resource_class, nil, transaction).should be_nil
    end
  end

  describe "#dns_update" do
    it "should update the DNS cache" do
      application.stub(:execute_command).and_return("EXECUTED")
      application.dns_update.should == "EXECUTED"
    end
  end

  describe "#resolver_path" do
    it "should return the resolver file basing on the configuration" do application.resolver_path.should == "/etc/resolver/#{application.config.tld}" end
    it "should return the resolver file basing on the argument" do application.resolver_path("foo").should == "/etc/resolver/foo" end
  end

  describe "#launch_agent_path" do
    it "should return the agent file with a default name" do application.launch_agent_path.should == ENV["HOME"] + "/Library/LaunchAgents/it.cowtech.devdnsd.plist" end
    it "should return the agent file with a specified name" do application.launch_agent_path("foo").should == ENV["HOME"] + "/Library/LaunchAgents/foo.plist" end
  end

  describe "#action_start" do
    it "should call perform_server in foreground" do
      application = DevDNSd::Application.instance({:log_file => log_file}, {:foreground => true}, [], true)
      application.should_receive(:perform_server)
      application.action_start
    end

    it "should start the daemon" do
      application = DevDNSd::Application.instance({:log_file => log_file}, {}, [], true)
      ::RExec::Daemon::Controller.should_receive(:start)
      application.action_start
    end
  end

  describe "#action_stop" do
    it "should stop the daemon" do
      ::RExec::Daemon::Controller.should_receive(:stop)
      application.action_stop
    end
  end

  describe "#action_install" do
    if ::Config::CONFIG['host_os'] =~ /^darwin/ then
      it "should create the resolver" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.action_install
        ::File.exists?(resolver_path).should be_true

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should create the agent" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.stub(:resolver_path).and_return(resolver_path)
        application.action_install
        ::File.exists?(application.launch_agent_path).should be_true

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should update the DNS cache" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.should_receive(:dns_update)
        application.action_install

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not create and invalid logger" do
        application.stub(:resolver_path).and_return("/invalid/resolver")
        application.stub(:launch_agent_path).and_return("/invalid/agent")
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.get_logger.should_receive(:error).with("Cannot create the resolver file.")
        application.action_install

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not create and invalid agent" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return("/invalid/agent")
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.get_logger.should_receive(:error).with("Cannot create the launch agent.")
        application.action_install

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load an invalid agent" do
        class DevDNSd::Application
          def execute_command(command)
            command =~ /^launchctl/ ? raise(StandardError) : system(command)
          end
        end

        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.get_logger.should_receive(:error).with("Cannot load the launch agent.")
        application.action_install

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end
    end

    it "should raise an exception if not running on OSX" do
      application.stub(:is_osx?).and_return(false)
      application.get_logger.should_receive(:fatal).with("Install DevDNSd as a local resolver is only available on MacOSX.")
      application.action_install.should be_false
    end
  end

  describe "#action_uninstall" do
    if ::Config::CONFIG['host_os'] =~ /^darwin/ then
      it "should remove the resolver" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.action_install
        application.action_uninstall
        ::File.exists?(resolver_path).should be_false

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should remove the agent" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        DevDNSd::Logger.stub(:default_file).and_return($stdout)
        application.action_install
        application.action_uninstall
        ::File.exists?(application.launch_agent_path).should be_false

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load delete an invalid resolver" do
        application.stub(:resolver_path).and_return("/invalid/resolver")
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.get_logger.should_receive(:warn).at_least(1)
        application.action_uninstall

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not delete an invalid agent" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.get_logger.should_receive(:warn).at_least(1)
        application.action_uninstall

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load delete invalid agent" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.stub(:execute_command).and_raise(StandardError)
        application.get_logger.should_receive(:warn).at_least(1)
        application.action_uninstall

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should update the DNS cache" do
        application.stub(:resolver_path).and_return(resolver_path)
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.action_install
        application.should_receive(:dns_update)
        application.action_uninstall

        ::File.unlink(application.resolver_path) if ::File.exists?(application.resolver_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end
    end

    it "should raise an exception if not running on OSX" do
      application.stub(:is_osx?).and_return(false)
      application.get_logger.should_receive(:fatal).with("Install DevDNSd as a local resolver is only available on MacOSX.")
      application.action_uninstall.should be_false
    end
  end
end