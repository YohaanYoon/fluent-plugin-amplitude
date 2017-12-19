require 'spec_helper'
require 'amplitude-api'
describe Fluent::AmplitudeOutput do
  describe '#format' do
    let(:amplitude_api) { double(:amplitude_api) }
    let(:now) { Time.now.to_i }
    let(:tag) { 'after_sign' }
    let(:amplitude) do
      Fluent::Test::BufferedOutputTestDriver.new(
        Fluent::AmplitudeOutput.new
      ).configure(conf)
    end
    let(:conf) do
      %(
        api_key XXXXXX
        user_id_key user_id
        device_id_key uuid
        insert_id_key event_uuid
        user_properties first_name, last_name
        event_properties current_source
      )
    end

    before do
      Fluent::Test.setup
      expect(AmplitudeAPI).to receive(:api_key=).with('XXXXXX')
      response = double(:response, response_code: 200)
      allow(AmplitudeAPI).to receive(:track).with(kind_of(Array)).and_return(
        response
      )
      allow(response).to receive(:total_time).and_return(123)
      allow_any_instance_of(Statsd).to receive(:track)
    end

    before do
      amplitude.tag = tag
      amplitude.emit(event, now)
    end

    context 'everything is set' do
      let(:event) do
        {
          'user_id' => 42,
          'uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710,
          'revenue_type' => 'sustainer',
          'quantity' => 2,
          'price' => 10.05,
          'revenue' => 20.10,
        }
      end

      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          price: 10.05,
          quantity: 2,
          revenue: 20.10,
          revenue_type: 'sustainer',
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end

      it 'produces the expected output' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end

    context 'the input only contains the user_id_key' do
      let(:event) do
        {
          'user_id' => 42,
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710
        }
      end
      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end
      it 'produces the expected output without device_id' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end

    context 'the input only contains the device_id field' do
      let(:event) do
        {
          'uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710
        }
      end
      let(:formatted_event) do
        {
          event_type: tag,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end
      it 'produces the expected output without user_id' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end

    context 'the input only contains neither user_id nor device_id field' do
      let(:event) do
        {
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710
        }
      end
      it 'does not track the event' do
        expect(AmplitudeAPI).to_not receive(:track)
        amplitude.run
      end
    end

    context 'the input only contains empty user_id and device_id fields' do
      let(:event) do
        {
          'user_id' => '',
          'uuid' => '',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710
        }
      end
      it 'does not track the event' do
        expect(AmplitudeAPI).to_not receive(:track)
        amplitude.run
      end
    end

    context 'properties_blacklist is specified' do
      let(:conf) do
        %(
          api_key XXXXXX
          user_id_key user_id
          device_id_key uuid
          user_properties first_name, last_name
          properties_blacklist foo, state
        )
      end

      let(:event) do
        {
          'user_id' => 42,
          'uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710,
          'foo' => 'bar'
        }
      end
      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share',
            recruiter_id: 710
          }
        }
      end
      it 'produces the expected output without blacklisted properties' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end

    context 'multiple user_id_key specified' do
      let(:conf) do
        %(
          api_key XXXXXX
          user_id_key user_id, another_user_id_field
          device_id_key uuid
          user_properties first_name, last_name
          event_properties current_source
        )
      end
      let(:event) do
        {
          'another_user_id_field' => 42,
          'uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710
        }
      end

      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end

      it 'produces the expected output' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end

    context 'multiple device_id_key specified' do
      let(:conf) do
        %(
          api_key XXXXXX
          user_id_key user_id
          device_id_key uuid, user_uuid
          user_properties first_name, last_name
          event_properties current_source
        )
      end
      let(:event) do
        {
          'user_id' => 42,
          'user_uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710
        }
      end

      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end

      it 'produces the expected output' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end
    context 'time_key specified' do
      let(:conf) do
        %(
          api_key XXXXXX
          user_id_key user_id
          device_id_key uuid
          time_key created_at
          user_properties first_name, last_name
          event_properties current_source
        )
      end
      let(:event) do
        {
          'user_id' => 42,
          'uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710,
          'created_at' => '2016-12-20T00:00:06Z'
        }
      end

      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          time: Time.parse('2016-12-20T00:00:06Z').to_i,
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end

      it 'produces the expected output' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end

    context 'insert_id_key specified' do
      let(:conf) do
        %(
          api_key XXXXXX
          user_id_key user_id
          device_id_key uuid
          time_key created_at
          insert_id_key event_uuid
          user_properties first_name, last_name
          event_properties current_source
        )
      end
      let(:event) do
        {
          'user_id' => 42,
          'uuid' => 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          'first_name' => 'Bobby',
          'last_name' => 'Weir',
          'state' => 'CA',
          'current_source' => 'fb_share',
          'recruiter_id' => 710,
          'created_at' => '2016-12-20T00:00:06Z',
          'event_uuid' => '330e62a4-1e3b-48fc-975f-07771ea6f474',
        }
      end

      let(:formatted_event) do
        {
          event_type: tag,
          user_id: 42,
          device_id: 'e6153b00-85d8-11e6-b1bc-43192d1e493f',
          insert_id: '330e62a4-1e3b-48fc-975f-07771ea6f474',
          time: Time.parse('2016-12-20T00:00:06Z').to_i,
          user_properties: {
            first_name: 'Bobby',
            last_name: 'Weir'
          },
          event_properties: {
            current_source: 'fb_share'
          }
        }
      end

      it 'produces the expected output' do
        amplitude.expect_format [tag, now, formatted_event].to_msgpack
        amplitude.run
      end
    end
  end

  describe 'log_error' do
    it 'logs an error to the console' do
      plugin = Fluent::AmplitudeOutput.new
      message = 'Response: 429, Body: This is the body, Duration: 2000'

      expect_any_instance_of(Statsd).to receive(:track).with(
        'fluentd.amplitude.records_errored', 3
      )
      expect(plugin.log).to receive(:error).with(message)
      plugin.send(:log_error,
        code: 429,
        body: 'This is the body',
        records: ['foo', 'bar', 'baz'],
        duration: 2000
      )
    end
  end
end
