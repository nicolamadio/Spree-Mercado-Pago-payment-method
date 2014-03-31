# -*- encoding : utf-8 -*-
require 'rest_client'


class MercadoPagoException < Exception
end

class SpreeMercadoPagoClient
  # These three includes are because of the user of line_item_description from
  # ProductsHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
  include Spree::ProductsHelper

  include MercadoPago::Authenticator
  include MercadoPago::Preferences
  include MercadoPago::Search

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


  private

  def log_error(msg, response, request, result)
    Rails.logger.info msg
    Rails.logger.info "response: #{response}."
    Rails.logger.info "request args: #{request.args}."
    Rails.logger.info "result #{result}."
  end

  def client_id
    @payment_method.preferred_client_id
  end

  def client_secret
    @payment_method.preferred_client_secret
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

  def create_url(url, params={})
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

end
