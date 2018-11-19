require 'faraday'

module FakeAuth
  class Error < RuntimeError; end

  class Client
    def initialize
      @http = Faraday.new('https://auth.example.com') do |conn|
        conn.adapter :test do |stub|
          stub.post('/login') { [200, {}, {username: 'Bob'}.to_json] }
        end
      end
    end

    def login
      response = @http.post('/login')
      if response.status == 200
        JSON.parse(response.body)
      else
        raise Error, 'login failed'
      end
    end
  end
end
