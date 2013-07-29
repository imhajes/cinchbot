#!/usr/bin/env ruby

# Global variables
$AUTHOR  = 'Donovan C. Young'
$VERSION = 'v1.2'
$PROGRAM = "#{File.basename($PROGRAM_NAME).gsub('.rb', '')}" 

LIB = File.expand_path(File.dirname(__FILE__)) + '/lib'

require 'rubygems'
require 'bundler/setup'
require 'pp'
require 'yaml'
require 'thwait'
require 'sequel'
require 'cinch'
require 'cinch/extensions/authentication'

require "#{LIB}/optparse"
require "#{LIB}/botconfig"

# Parse command line arguments
$options = OptParse.parse(ARGV)

# Load and process the config file
$config  = CinchBot::Config.new( $options.conf_file ) || exit

# Create a threadswait container
threads = ThreadsWait.new

# cycle through the configured networks and start our bot(s)
$config.networks.each do |name, network|
    Thread.abort_on_exception = true    # Show exceptions as they happen
    thread = Thread.new do
        bot = Cinch::Bot.new do
            configure do |c|
                # Authentication configuration
                c.authentication          = Cinch::Configuration::Authentication.new
                c.authentication.level    = :users
                c.authentication.strategy = :list
                c.authentication.level    = [:owner, :admins, :users]

                # Plugin configuration
                c.plugins.plugins = $config.plugins

                # Set defaults (may be overwritten below)
                $config.defaults.each { |key, value| c.send( "#{key}=".to_sym, value ) }

                # Server configuration
                network.server.each do |key, value| 
                    case key
                    when /^sasl$/i
                        c.sasl.username = value['username']
                        c.sasl.password = value['password']
                    when /^auth$/i
                        c.authentication.owner    = [ value['owner'] ]
                        c.authentication.admins   = c.authentication.owner  + ( value['admins'] || [] )
                        c.authentication.users    = c.authentication.admins + ( value['users']  || [] )
                    else
                        c.send( "#{key}=".to_sym, value )
                    end
                end
            end
        end

        puts "Starting connection to #{bot.config.server}" if $options.verbose
        pp bot.config if $options.debug
        bot.start unless $options.pretend
    end

    threads.join_nowait( thread )
end

sleep 1 while threads.all_waits 

puts "That's all folks." if $options.verbose
