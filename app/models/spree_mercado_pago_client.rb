# -*- encoding : utf-8 -*-
require 'rest_client'

class SpreeMercadoPagoClient
  # These three includes are because of the user of line_item_description from
  # ProductsHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
  include Spree::ProductsHelper

  attr_reader :errors
  attr_reader :auth_response
  attr_reader :preferences_response

  def initialize(order, callbacks, options={})
    unless callbacks[:success] && callbacks[:pending] && callbacks[:failure]
      raise "Url callbacks where not specified"
    end

    @api_options = options.clone
    @order = order
    @callbacks = callbacks
    @errors = []
    config_options
  end

  def authenticate
    response = send_authentication_request

    if response.code != 200
      @auth_response = nil
      @errors << I18n.t(:mp_authentication_error)
    else
      @errors = []
      @auth_response = ActiveSupport::JSON.decode(response)
    end

    @auth_response
  end

  def send_data
    response = send_preferences_request

    if response.code != 201
      @preferences_response = nil
      @errors << I18n.t(:mp_preferences_setup_error)
    else
      @errors = []
      @preferences_response = ActiveSupport::JSON.decode(response)
    end

    @preferences_response
  end

  def redirect_url
    point_key = ( if sandbox then 'sandbox_init_point' else 'init_point' end)

    @preferences_response[point_key] if @preferences_response.present?

  end

  private
  def send_authentication_request
    response = RestClient.post(
      'https://api.mercadolibre.com/oauth/token',
      {:grant_type => 'client_credentials', :client_id => client_id, :client_secret => client_secret},
      :content_type=> "application/x-www-form-urlencoded", :accept => 'application/json'
    )
  end

  def send_preferences_request
    RestClient.post(
      mp_preferences_url(@auth_response["access_token"]),
      @options.to_json,
      :content_type=> 'application/json', :accept => 'application/json'
    )
  end

  def client_id
    @api_options[:payment].payment_method.preferred_client_id
  end

  def client_secret
    @api_options[:payment].payment_method.preferred_client_secret
  end

  def mp_preferences_url(token)
    "https://api.mercadolibre.com/checkout/preferences?access_token=#{token}"
  end

  def sandbox
    @api_options[:sandbox]
  end

  def config_options
    @options = Hash.new
    @options[:external_reference] = @api_options[:payment].id
    @options[:back_urls] = {
      :success => @callbacks[:success],
      :pending => @callbacks[:pending],
      :failure => @callbacks[:failure]
    }
    @options[:items] = Array.new

    @order.line_items.each do |li|
      h = {
        :title => line_item_description_text(li.variant.product.description),
        :unit_price => li.price.to_f,
        :quantity => li.quantity,
        :currency_id => "ARS"
      }
      @options[:items] << h
    end
  end
end
