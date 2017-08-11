require 'fluent/plugin/fake_active_support'
module Fluent
  # Fluent::AmplitudeOutput plugin
  class AmplitudeOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('amplitude', self)

    include Fluent::HandleTagNameMixin
    include FakeActiveSupport

    REVENUE_PROPERTIES = %w(
      price
      quantity
      revenue
      revenue_type
    ).freeze

    config_param :api_key, :string, secret: true
    config_param :device_id_key, :array, default: nil
    config_param :user_id_key, :array, default: nil
    config_param :time_key, :array, default: nil
    config_param :user_properties, :array, default: nil
    config_param :event_properties, :array, default: nil
    config_param :properties_blacklist, :array, default: nil
    config_param :events_whitelist, :array, default: nil
    config_param :events_blacklist, :array, default: nil

    class AmplitudeError < StandardError; end

    def initialize
      super
      require 'amplitude-api'
    end

    def configure(conf)
      super
      raise Fluent::ConfigError, "'api_key' must be specified." if @api_key.nil?

      invalid = @device_id_key.nil? && @user_id_key.nil?
      raise Fluent::ConfigError,
            "'device_id_key' or 'user_id_key' must be specified." if invalid
    end

    def start
      super
      AmplitudeAPI.api_key = @api_key
    end

    def format(tag, time, record)
      amplitude_hash = { event_type: tag }

      filter_properties_blacklist!(record)
      extract_user_and_device!(amplitude_hash, record)
      set_time!(amplitude_hash, record)
      extract_revenue_properties!(amplitude_hash, record)
      extract_user_properties!(amplitude_hash, record)
      extract_event_properties!(amplitude_hash, record)

      [tag, time, amplitude_hash].to_msgpack
    end

    def write(chunk)
      records = []
      chunk.msgpack_each do |tag, _time, record|
        next if @events_whitelist && !@events_whitelist.include?(tag)
        next if @events_blacklist && @events_blacklist.include?(tag)
        record = simple_symbolize_keys(record)
        if verify_user_and_device(record)
          records << AmplitudeAPI::Event.new(record)
        else
          log.info(
            "Error: either user_id or device_id must be set for tag #{tag}"
          )
        end
      end

      send_to_amplitude(records) unless records.empty?
    end

    private

    def filter_properties_blacklist!(record)
      return unless @properties_blacklist
      record.reject! { |k, _| @properties_blacklist.include?(k) }
    end

    def extract_user_and_device!(amplitude_hash, record)
      if @user_id_key
        @user_id_key.each do |user_id_key|
          if record[user_id_key]
            amplitude_hash[:user_id] = record.delete(user_id_key)
            break
          end
        end
      end
      if @device_id_key
        @device_id_key.each do |device_id_key|
          if record[device_id_key]
            amplitude_hash[:device_id] = record.delete(device_id_key)
            break
          end
        end
      end
    end

    def verify_user_and_device(amplitude_hash)
      user_id = amplitude_hash[:user_id]
      device_id = amplitude_hash[:device_id]
      present?(user_id) || present?(device_id)
    end

    def set_time!(amplitude_hash, record)
      return unless @time_key && !@time_key.empty?
      @time_key.each do |time_key|
        next unless record[time_key]
        if (time = parse_time_from_string(record[time_key]))
          amplitude_hash[:time] = time
          break
        end
      end
    end

    def parse_time_from_string(time_string)
      # this should be seconds since epoch; amplitude-api
      # converts it to milliseconds since epoch as needed.
      Time.parse(time_string).to_i
    rescue StandardError => e
      log.info("failed to parse #{time_string}: #{e.message}")
    end

    def extract_revenue_properties!(amplitude_hash, record)
      REVENUE_PROPERTIES.each do |prop|
        next if record[prop].nil?

        amplitude_hash[prop.to_sym] = record.delete(prop)
      end
    end

    def extract_user_properties!(amplitude_hash, record)
      # if user_properties are specified, pull them off of the record
      return unless @user_properties
      amplitude_hash[:user_properties] = {}.tap do |user_properties|
        @user_properties.each do |prop|
          next unless record[prop]
          user_properties[prop.to_sym] = record.delete(prop)
        end
      end
    end

    def extract_event_properties!(amplitude_hash, record)
      # if event_properties are specified, pull them off of the record
      # otherwise, use the remaining record (minus any revenue_properties and user_properties)
      amplitude_hash[:event_properties] = begin
        if @event_properties
          record.select do |k, _v|
            @event_properties.include?(k)
          end
        else
          record
        end
      end
    end

    def send_to_amplitude(records)
      log.info("sending #{records.length} to amplitude")
      errors = []
      until records.empty?
        records_to_send = records.pop(500)
        start_time = Time.now.to_i
        res = AmplitudeAPI.track(records_to_send)
        unless res.response_code == 200
          fail_time = Time.now.to_i
          errors << [res.response_code, res.body, records_to_send, fail_time - start_time]
        end
      end
      log_errors(errors)
    end

    def log_errors(errors)
      return if errors.empty?
      errors_string = errors.map do |code, body, records, time|
        "Response: #{code}, Time: #{time}, Body: #{body}, Record: #{records}"
      end
      raise AmplitudeError, "Errors: #{errors_string}"
    end
  end
end
