module Dea
  class StatCollector
    INTERVAL = 10

    attr_reader :used_memory_in_bytes
    attr_reader :used_disk_in_bytes
    attr_reader :computed_pcpu    # See `man ps`

    def initialize(container)
      @container = container
      @used_memory_in_bytes = 0
      @used_disk_in_bytes = 0
      @computed_pcpu = 0
      @cpu_samples = []
    end

    def start
      start_stat_collector
    end

    def stop
      stop_stat_collector
    end

    def retrieve_stats(now)
      info = @container.info
    rescue => e
      logger.error "stat-collector.info-retrieval.failed",
        :handle => @container.handle,
        :error => e, :backtrace => e.backtrace
    else
      @used_memory_in_bytes = info.memory_stat.rss * 1024
      @used_disk_in_bytes = info.disk_stat.bytes_used
      compute_cpu_usage(info.cpu_stat.usage, now)
    end

    private

    def start_stat_collector
      return false if @run_stat_collector

      @run_stat_collector = true

      run_stat_collector

      true
    end

    def stop_stat_collector
      @run_stat_collector = false

      if @run_stat_collector_timer
        @run_stat_collector_timer.cancel
        @run_stat_collector_timer = nil
      end
    end

    def run_stat_collector
      retrieve_stats(Time.now)

      if @run_stat_collector
        @run_stat_collector_timer =
          ::EM::Timer.new(INTERVAL) do
            run_stat_collector
          end
      end
    end

    def compute_cpu_usage(usage, now)
      @cpu_samples << {
        :timestamp_ns => now.to_i * 1_000_000_000 + now.nsec,
        :ns_used      => usage,
      }

      @cpu_samples.shift if @cpu_samples.size > 2

      if @cpu_samples.size == 2
        used = @cpu_samples[1][:ns_used] - @cpu_samples[0][:ns_used]
        elapsed = @cpu_samples[1][:timestamp_ns] - @cpu_samples[0][:timestamp_ns]

        if elapsed > 0
          @computed_pcpu = used.to_f / elapsed
        end
      end
    end
  end
end