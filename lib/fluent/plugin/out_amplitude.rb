require 'fluent/plugin/fake_active_support'
module Fluent
  # Fluent::AmplitudeOutput plugin
  class AmplitudeOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('amplitude', self)

    include Fluent::HandleTagNameMixin
    include FakeActiveSupport

    config_param :api_key, :string, secret: true
    config_param :device_id_key, :array, default: nil
    config_param :user_id_key, :array, default: nil
    config_param :user_properties, :array, default: nil
    config_param :event_properties, :array, default: nil
    config_param :properties_blacklist, :array, default: nil
    config_param :events_whitelist, :array, default: nil
    class AmplitudeError < StandardError
    end

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
      return if @events_whitelist && !@events_whitelist.include?(tag)

      amplitude_hash = { event_type: tag }

      filter_properties_blacklist!(record)
      extract_user_and_device_or_fail!(amplitude_hash, record)
      extract_user_properties!(amplitude_hash, record)
      extract_event_properties!(amplitude_hash, record)

      [tag, time, amplitude_hash].to_msgpack
    end

    def write(chunk)
      records = []
      chunk.msgpack_each do |_tag, _time, record|
        records << AmplitudeAPI::Event.new(simple_symbolize_keys(record))
      end

      send_to_amplitude(records)
    end

    private

    def filter_properties_blacklist!(record)
      return unless @properties_blacklist
      record.reject! { |k, _| @properties_blacklist.include?(k) }
    end

    def extract_user_and_device_or_fail!(amplitude_hash, record)
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

      verify_user_and_device_or_fail(amplitude_hash)
    end

    def verify_user_and_device_or_fail(amplitude_hash)
      user_id = amplitude_hash[:user_id]
      device_id = amplitude_hash[:device_id]
      return if present?(user_id) || present?(device_id)
      raise AmplitudeError, 'Error: either user_id or device_id must be set'
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
      # otherwise, use the remaining record (minus any user_properties)
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
      begin
        res = AmplitudeAPI.track(records)
        unless res.response_code == 200
          raise "Got #{res.response_code} #{res.body} from AmplitudeAPI"
        end
      rescue StandardError => e
        raise AmplitudeError, "Error: #{e.message}"
      end
    end
  end
end
