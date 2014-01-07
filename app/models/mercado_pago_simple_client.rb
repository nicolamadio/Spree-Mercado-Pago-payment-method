require 'rest-client'
require 'active_support/json/decoding'

class MercadoPagoSimpleClient
  attr_accessor :auth_url, :preferences_url

  def initialize(client_id, client_secret, options={})
    @client_id = client_id
    @client_secret = client_secret
    @sandbox = options[:sandbox]
    self.auth_url = options[:auth_url] || 'https://api.mercadolibre.com/oauth/token'
    self.preferences_url = options[:preferences_url] || 'https://api.mercadolibre.com/checkout/preferences'
  end


  def access_token
    @auth_response ||= find_access_token
    @auth_response['access_token']
  end

  def status(operation_id)
    operation_status(operation_id)['collection']['status']
  end

  def approved?(operation_id)
    status_equals operation_id, 'approved'
  end

  def pending?(operation_id)
    status_equals operation_id, 'pending'
  end

  def operation_status(operation_id)
    url =ipn_url(operation_id, {access_token:access_token})
    puts url
    response = RestClient.get(url,
        :content_type=> 'application/json', :accept => 'application/json'
    )
    ActiveSupport::JSON.decode(response)
  end

  private

  def status_equals(operation_id, expected_status)
    status(operation_id) == expected_status
  end

  def ipn_url(operation_id, params={})
    sandbox = @sandbox ? 'sandbox/' : ''
    url_string = "https://api.mercadolibre.com/#{sandbox}collections/notifications/#{operation_id}"
    uri = URI(url_string)
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

  def find_access_token
    response = RestClient.post(
        self.auth_url,
        {:grant_type => 'client_credentials', :client_id => @client_id, :client_secret => @client_secret},
        :content_type=> 'application/x-www-form-urlencoded', :accept => 'application/json'
    )
    ActiveSupport::JSON.decode(response)
  end

end