#!/usr/bin/env ruby
require 'rufus-scheduler'
require 'pp'
require 'ecobee'
require 'collectd'
require 'yaml'

SCHEDULER = Rufus::Scheduler.new

config = YAML::load_file('config.yaml')

puts "Starting poller"
puts "Collectd server: #{config['server']} port: #{config['port']}"

Collectd.add_server(10, config['server'], config['port'])

stats = Hash.new
hum_stats = Hash.new

SCHEDULER.every '30s' do
    load_lambda = lambda do |config|
      config
    end

    save_lambda = lambda do |config|
      config
    end
    puts "helo"

    token = Ecobee::Token.new(
      app_key: 'OConrCoYN4Cx6n5Dh0T7k8VghUg4yJOW',
      callbacks: {
        load: load_lambda,
        save: save_lambda
      }
    )
    if token.pin
        puts "Use registration tool to register app"
        return
    end
    thermostat = Ecobee::Thermostat.new(token: token)
    sensors = thermostat[:remoteSensors].map do |sensor|
        s = {
            :name => sensor[:name]
        }
        sensor[:capability].each do |cap|
            if cap[:type] == "temperature"
                s[:temp] = thermostat.unitize(cap[:value])
            elsif cap[:type] == "occupancy"
                s[:occupancy] = cap[:value]
            elsif cap[:type] == "humidity"
                s[:humidity] = cap[:value]
            end
        end
        if !stats.key?(s[:name])
            stats[s[:name]] = Collectd.ecobee(s[:name])
        end
        stat = stats[s[:name]]
        stat.temperature(:temperature).gauge= s[:temp]
        if s.key?(:occupancy)
            stat.occupancy(:occupancy).gauge=s[:occupancy]
        end
        if s.key?(:humidity)
            stat.humidity(:humidity).gauge=s[:humidity]
        end
        puts s
        {
            :label => s[:name],
            :value => "#{thermostat.unitize(s[:temp])} - #{s[:occupancy] == "true" ? 'Occupied' : 'Unoccupied'}"
        }
    end
    puts "end"
end

SCHEDULER.join

