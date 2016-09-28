# encoding: UTF-8
require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)
Bundler.require(:default, :test)

require 'fluent/test'
require 'rspec'

Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'fluent/plugin/out_amplitude'
