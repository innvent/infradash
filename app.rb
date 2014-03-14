require 'sinatra/base'
require 'pry'
require 'libvirt'
require 'yaml'
require 'json'
require_relative 'models/models'

module Infradash
  class App < Sinatra::Base

    def initialize(app = nil, params = {})
      super(app)

      conf = YAML.load_file('app.yml')

      @hypervisors = conf['hosts'].map do |host|

        if host['type'] == 'libvirt' then
          hypervisor = Struct.new(:address) do
            def connect
              Hypervisor::Libvirt.connect(address) { |h| yield h }
            end
          end
        else
          abort "Hypervisor #{host['type']} not supported."
        end

        hypervisor.new(host['address'])
      end
    end

    get '/domain' do
      domains = []
      @hypervisors.each do |host|
        host.connect do |hypervisor| 
          host_domains = hypervisor.query.map do |domain|
            {
              id: domain.id,
              name: domain.name,
              state: domain.state
            }
          end
          domains += host_domains
        end
      end

      content_type :json
      domains.to_json
    end

    get '/domain/:name' do

      @hypervisors.each do |host|
        host.connect do |hypervisor| 
          domain = hypervisor.get(params[:name])
          unless domain.nil? then

            content_type :json
            return {
              id: domain.id,
              name: domain.name,
              state: domain.state,
              cpu: domain.cpu,
              memory: domain.memory
            }.to_json

          end
        end
      end

      halt 404
    end

    run! if app_file = $0
  end
end