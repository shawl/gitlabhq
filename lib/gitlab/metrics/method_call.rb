module Gitlab
  module Metrics
    # Class for tracking timing information about method calls
    class MethodCall
      BASE_LABELS = { module: nil, method: nil }.freeze
      attr_reader :real_time, :cpu_time, :call_count

      def self.call_real_duration_histogram
        @call_real_duration_histogram ||= Gitlab::Metrics.histogram(
          :gitlab_method_call_real_duration_seconds,
          'Method calls real duration',
          Transaction::BASE_LABELS.merge(BASE_LABELS),
          [0.1, 0.2, 0.5, 1, 2, 5, 10]
        )
      end

      def self.call_cpu_duration_histogram
        @call_duration_histogram ||= Gitlab::Metrics.histogram(
          :gitlab_method_call_cpu_duration_seconds,
          'Method calls cpu duration',
          Transaction::BASE_LABELS.merge(BASE_LABELS),
          [0.1, 0.2, 0.5, 1, 2, 5, 10]
        )
      end

      # name - The full name of the method (including namespace) such as
      #        `User#sign_in`.
      #
      def initialize(name, module_name, method_name, transaction)
        @module_name = module_name
        @method_name = method_name
        @transaction = transaction
        @name = name
        @real_time = 0
        @cpu_time = 0
        @call_count = 0
      end

      # Measures the real and CPU execution time of the supplied block.
      def measure
        start_real = System.monotonic_time
        start_cpu = System.cpu_time
        retval = yield

        real_time = System.monotonic_time - start_real
        cpu_time = System.cpu_time - start_cpu

        @real_time += real_time
        @cpu_time += cpu_time
        @call_count += 1

        self.class.call_real_duration_histogram.observe(@transaction.labels.merge(labels), real_time / 1000.0)
        self.class.call_cpu_duration_histogram.observe(@transaction.labels.merge(labels), cpu_time / 1000.0)

        retval
      end

      def labels
        @labels ||= { module: @module_name, method: @method_name }
      end

      # Returns a Metric instance of the current method call.
      def to_metric
        Metric.new(
          Instrumentation.series,
          {
            duration: real_time,
            cpu_duration: cpu_time,
            call_count: call_count
          },
          method: @name
        )
      end

      # Returns true if the total runtime of this method exceeds the method call
      # threshold.
      def above_threshold?
        real_time >= Metrics.method_call_threshold
      end
    end
  end
end
