require 'rubygems'
require 'test/unit'
$: << "." unless $:.include?(".") # for Ruby 1.9.2
$:.unshift File.dirname(__FILE__) + '/../lib'
require File.dirname(__FILE__) + '/../lib/float-formats'
