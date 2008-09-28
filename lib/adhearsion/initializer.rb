module Adhearsion
  
  class PathString < String
    attr_accessor :component_path, :dialplan_path, :log_path
    
    def initialize(path)
      super
      defaults
    end
    
    def defaults
      @component_path = build_path_for "components"
      @dialplan_path  = dup
      @log_path       = build_path_for "logs"
    end

    def base_path=(value)
      replace(value)
      defaults
    end
    
    def using_base_path(temporary_base_path, &block)
      original_path = dup
      self.base_path = temporary_base_path
      block.call
    ensure
      self.base_path = original_path
    end
    
    def dial_plan_named(name)
      File.join(dialplan_path, name)
    end
    
    private
      def build_path_for(path)
        File.join(to_s, path)
      end
  end
  
  class Initializer
    
    class << self
      def get_rules_from(location)
        location = File.join location, ".ahnrc" if File.directory? location
        File.exists?(location) ? YAML.load_file(location) : nil
      end
      
      def ahn_root=(path)
        if Object.constants.include?("AHN_ROOT")
          Object.const_get(:AHN_ROOT).base_path = File.expand_path(path)
        else
          Object.const_set(:AHN_ROOT, PathString.new(File.expand_path(path)))
        end
      end
      
      def start(*args, &block)
        new(*args, &block).start
      end
      
      def start_from_init_file(file, ahn_app_path)
        return if defined?(@@started) && @@started
        start ahn_app_path, :loaded_init_files => file
      end
      
    end
  
    attr_reader :path, :daemon, :pid_file, :log_file, :ahn_app_log_directory
    
    DEFAULT_FRAMEWORK_EVENT_NAMESPACES = %w[
      /framework/after_initialized
      /framework/shutdown
    ]
    
    # Creation of pid_files
    #
    #  - You may want to have Adhearsion create a process identification
    #    file when it boots so that a crash monitoring program such as
    #    Monit can reboot if necessary or so the init script can kill it
    #    for system shutdowns.
    #  - To have Adhearsion create a pid file in the default location (i.e.
    #    AHN_INSTALL_DIR/adhearsion.pid), supply :pid_file with 'true'. Otherwise
    #    one is not created UNLESS it is running in daemon mode, in which
    #    case one is created. You can force Adhearsion to not create one
    #    even in daemon mode by supplying "false".
    def initialize(path=nil, options={})
      @@started = true
      @path     = path
      @daemon   = options[:daemon]
      @pid_file = options[:pid_file].nil? ? ENV['PID_FILE'] : options[:pid_file]
      @loaded_init_files  = options[:loaded_init_files]
    end
    
    def start
      self.class.ahn_root = path
      resolve_pid_file_path
      resolve_log_file_path
      switch_to_root_directory
      catch_termination_signal
      bootstrap_rc
      load_all_init_files
      init_modules
      daemonize! if should_daemonize?
      initialize_log_file
      create_pid_file if pid_file
      load_components
      init_events
      ahn_log "Adhearsion initialized!"
      
      trigger_after_initialized_hooks
      join_framework_threads
      
      self
    end
    
    def init_events
        # 
        # framework = 
        # DEFAULT_FRAMEWORK_EVENT_NAMESPACES.each do |namespace|
        #   .register_callback_name framework_event_callback_name
        # end
        ############
        # else #...
        # ahn_log.events.warn 'No "events" section in .ahnrc. Skipping its initialization.'
    end
    
    def initialize_log_file
      Dir.mkdir(ahn_app_log_directory) unless File.directory? ahn_app_log_directory
      file_logger = Log4r::FileOutputter.new("Main Adhearsion log file", :filename => log_file, :trunc => false)
      
      if should_daemonize?
        Logging::AdhearsionLogger.outputters  = file_logger
      else
        Logging::AdhearsionLogger.outputters << file_logger
      end
      Logging::DefaultAdhearsionLogger.redefine_outputters
    end
    
    def resolve_log_file_path      
      @ahn_app_log_directory = AHN_ROOT + '/log'
      @log_file = File.expand_path(ahn_app_log_directory + "/adhearsion.log")
    end
    
    def create_pid_file(file = pid_file)
      if file
        File.open pid_file, 'w' do |file|
          file.puts Process.pid
        end
        
        Hooks::TearDown.create_hook do
          File.delete(pid_file) if File.exists?(pid_file)
        end
      end
    end
    
    def init_modules
      require 'adhearsion/initializer/database.rb'
      require 'adhearsion/initializer/asterisk.rb'
      require 'adhearsion/initializer/drb.rb'
      require 'adhearsion/initializer/rails.rb'
      # require 'adhearsion/initializer/freeswitch.rb'
      
      DatabaseInitializer.start if AHN_CONFIG.database_enabled?
      AsteriskInitializer.start if AHN_CONFIG.asterisk_enabled?
      DrbInitializer.start      if AHN_CONFIG.drb_enabled?
      RailsInitializer.start    if AHN_CONFIG.rails_enabled?
      # FreeswitchInitializer.start if AHN_CONFIG.freeswitch_enabled?
    end
    
    def resolve_pid_file_path
      @pid_file = if pid_file.equal?(true) then default_pid_path
      elsif pid_file then pid_file
      elsif pid_file.equal?(false) then nil
      # FIXME @pid_file = @daemon? Assignment or equality? I'm assuming equality.
      else @pid_file = @daemon ? default_pid_path : nil
      end
    end
    
    def switch_to_root_directory
      Dir.chdir AHN_ROOT
    end
    
    def catch_termination_signal
      Hooks::TearDown.catch_termination_signals
    end
    
    def load_all_init_files
      init_files_from_rc = AHN_CONFIG.files_from_setting("paths", "init").map { |file| File.expand_path(file) }
      already_loaded_init_files = Array(@loaded_init_files).map { |file| File.expand_path(file) }
      (init_files_from_rc - already_loaded_init_files).each { |init| load init }
    end
    
    def should_daemonize?
      @daemon || ENV['DAEMON']
    end
    
    def daemonize!
      ahn_log "Daemonizing now! Creating #{pid_file}."
      extend Adhearsion::CustomDaemonizer
      daemonize log_file
    end
    
    def load_components
      ComponentManager.load
      ComponentManager.start
    end
    
    def trigger_after_initialized_hooks
      Hooks::AfterInitialized.trigger_hooks
    end
    
    def join_framework_threads
      Hooks::ThreadsJoinedAfterInitialized.trigger_hooks
    end
    
    def bootstrap_rc
      rules = self.class.get_rules_from AHN_ROOT
      
      AHN_CONFIG.ahnrc = rules
      
      gems = rules['gems']
      if gems.kind_of?(Hash) && gems.any? && respond_to?(:gem)
        gems.each_pair do |gem_name,properties_hash|
          if properties_hash && properties_hash["version"]
            gem gem_name, properties_hash["version"]
          else
            gem gem_name
          end
          if properties_hash
            case properties_hash["require"]
              when Array
                properties_hash["require"].each { |lib| require lib }
              when String
                require properties_hash["require"]
            end 
          end
        end
      end
    end
    
    def default_pid_path
      File.join AHN_ROOT, 'adhearsion.pid'
    end
    
    class InitializationFailedError < Exception; end
  end
end
