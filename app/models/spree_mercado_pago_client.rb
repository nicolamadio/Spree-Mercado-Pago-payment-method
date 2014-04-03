# -*- encoding : utf-8 -*-
require 'rest_client'
require 'client/authentication'
require 'client/preferences'

class MercadoPagoException < Exception
end

class SpreeMercadoPagoClient
  # These three includes are because of the user of line_item_description from
  # ProductsHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
  include Spree::ProductsHelper

  include Authentication
  include Preferences


  attr_reader :errors
  attr_reader :auth_response
  attr_reader :preferences_response

  def initialize(payment_method, options={})
    @payment_method = payment_method
    @api_options = options.clone
    @errors = []
  end



  def redirect_url
    point_key = sandbox ? 'sandbox_init_point' : 'init_point'
    @preferences_response[point_key] if @preferences_response.present?
  end

  def get_external_reference(mercado_pago_id)
    response = send_notification_request mercado_pago_id
    if response
      response['collection']['external_reference']
    end
  end

  def get_payment_status(external_reference)
    response = send_search_request({:external_reference => external_reference, :access_token => access_token})
    response['results'][0]['collection']['status']
  end

  private


  def send_preferences_request(options)
    RestClient.post(preferences_url(access_token), options.to_json,
                    :content_type => 'application/json', :accept => 'application/json')
  end

  def log_error(msg, response, request, result)
    Rails.logger.info msg
    Rails.logger.info "response: #{response}."
    Rails.logger.info "request args: #{request.args}."
    Rails.logger.info "result #{result}."
  end

  def send_notification_request(mercado_pago_id)
    url = create_url(notifications_url(mercado_pago_id), access_token: @auth_response['access_token'])
    options = {:content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'}
    get(url, options, quiet: true)
  end

  def send_search_request(params, options={})
    url = create_url(search_url, params)
    options = {:content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'}
    get(url, options)
  end

  def access_token
    unless @auth_response
      authenticate
    end
    @auth_response['access_token']
  end

  def notifications_url(mercado_pago_id)
    sandbox_part = sandbox ? 'sandbox/' : ''
    "https://api.mercadolibre.com/#{sandbox_part}collections/notifications/#{mercado_pago_id}"
  end

  def search_url
    sandbox_part = sandbox ? 'sandbox/' : ''
    "https://api.mercadolibre.com/#{sandbox_part}collections/search"
  end

  def create_url(url, params={})
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

  def preferences_url(token)
    create_url 'https://api.mercadolibre.com/checkout/preferences', access_token: token
  end

  def sandbox
    @api_options[:sandbox]
  end

  def get(url, request_options={}, options={})
    response = RestClient.get(url, request_options)
    ActiveSupport::JSON.decode(response)
  rescue => e
    raise e unless options[:quiet]
  end


end
