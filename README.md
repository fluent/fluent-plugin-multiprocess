# Multiprocess agent plugin for Fluentd

## multiprocess

**multiprocess** agent plugin runs some child fluentd processes.
You can take advantage of multiple CPU cores using this plugin.

Please note that this plugin does not generate records although this is an input plugin.
This plugin just controls start & shutdown of child processes.


### Configuration

    <source>
      type multiprocess

      # optional:
      #graceful_kill_interval 2s
      #graceful_kill_interval_increment 3s
      #graceful_kill_timeout 60s

      <process>
        cmdline -c /etc/fluent/fluentd_child1.conf --log /var/log/fluent/fluentd_child1.log
      </process>
      <process>
        cmdline -c /etc/fluent/fluentd_child2.conf --log /var/log/fluent/fluentd_child2.log
        sleep_before_start 5s
      </process>
      <process>
        cmdline -c /etc/fluent/fluentd_child3.conf --log /var/log/fluent/fluentd_child3.log
        sleep_before_shutdown 5s
      </process>
    </source>

- **process** section sets command line arguments of a child process. This plugin creates one child process for each \<process\> section
- **cmdline** option is required in a \<process\> section
- **sleep\_before\_start** sets wait time before starting the process. Note that child processes **start from last to first** (`fluentd_child3` -\> `sleep 5` -\> { `fluentd_child2`, `fluentd_child1` } in this case)
- **sleep\_before\_shutdown** sets wait time before shutting down the process. Note that child processes **shutdown from first to last** ({ `fluentd_child1`, `fluentd_child2` } -\> `sleep 5` -> `fluentd_child3` in this case)

### Logs for daemonized processes

Daemonized fluentd closes its STDOUT. So child processes on daemonized fluentd & in_multiprocess doesn't put its logs without `--log` option. Specifing `--log` option always is best practice to help this situation.
