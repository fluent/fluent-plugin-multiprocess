#
# Fluent
#
# Copyright (C) 2013 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module Fluent

  class MultiprocessInput < Input
    Plugin.register_input('multiprocess', self)

    require 'shellwords'
    require 'serverengine'

    config_param :graceful_kill_interval, :time, :default => 2
    config_param :graceful_kill_interval_increment, :time, :default => 3
    config_param :graceful_kill_timeout, :time, :default => 60
    config_param :keep_file_descriptors, :bool, :default => nil

    class ProcessElement
      include Configurable

      config_param :cmdline, :string
      config_param :sleep_before_start, :time, :default => 0
      config_param :sleep_before_shutdown, :time, :default => 0
      config_param :keep_file_descriptors, :bool, :default => nil
      config_param :pid_file, :string, :default => nil

      attr_accessor :process_monitor
    end

    def configure(conf)
      super

      @processes = conf.elements.select {|e|
        e.name == 'process'
      }.map {|e|
        pe = ProcessElement.new
        pe.configure(e)
        pe
      }
    end

    def start
      @pm = ServerEngine::ProcessManager.new(
        :auto_tick => true,
        :auto_tick_interval => 1,
        :graceful_kill_interval => @graceful_kill_interval,
        :graceful_kill_interval_increment => @graceful_kill_interval_increment,
        :graceful_kill_timeout => @graceful_kill_timeout,
        :graceful_kill_signal => 'TERM',
        :immediate_kill_timeout => 0,  # disabled
      )

      plugin_rb = $LOADED_FEATURES.find {|x| x =~ /fluent\/plugin\.rb\z/ }
      fluentd_rb = File.join(File.dirname(plugin_rb), 'command', 'fluentd.rb')

      @processes.reverse_each do |pe|
        cmd = "#{Shellwords.shellescape(RbConfig.ruby)} #{Shellwords.shellescape(fluentd_rb)} #{pe.cmdline}"
        sleep pe.sleep_before_start if pe.sleep_before_start > 0
        $log.info "launching child fluentd #{pe.cmdline}"
        keep_file_descriptors = pe.keep_file_descriptors.nil? ? @keep_file_descriptors : pe.keep_file_descriptors
        options = {:close_others => !keep_file_descriptors}
        pe.process_monitor = @pm.spawn(cmd, options)

        create_pid_file(pe) if pe.pid_file
      end
    end

    def shutdown
      @processes.each {|pe|
        sleep pe.sleep_before_shutdown if pe.sleep_before_shutdown > 0
        $log.info "shutting down child fluentd #{pe.cmdline}"
        pe.process_monitor.start_graceful_stop!
      }
      @processes.each {|pe|
        pe.process_monitor.join
      }
      @processes.each { |pe|
        delete_pid_file(pe) if pe.pid_file
      }
    end

    def create_pid_file(pe)
      File.open(pe.pid_file, "w") { |f|
        f.write pe.process_monitor.pid
      }
    end

    def delete_pid_file(pe)
      File.unlink(pe.pid_file) if File.exist?(pe.pid_file)
    end
  end

end
