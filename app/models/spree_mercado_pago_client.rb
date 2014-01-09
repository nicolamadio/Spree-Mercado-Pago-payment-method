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

  attr_reader :errors
  attr_reader :auth_response
  attr_reader :preferences_response

  def initialize(payment_method, options={})
    @payment_method = payment_method
    @api_options = options.clone
    @errors = []
  end

  def authenticate
    response = send_authentication_request

    if response.code != 200
      @errors << I18n.t(:mp_authentication_error)
      raise MercadoPagoException.new
    end

    @auth_response = ActiveSupport::JSON.decode(response)
  end

  def create_preference(order, payment, success_callback,
      pending_callback, failure_callback)

    options = create_preference_options order, payment, success_callback,
                                        pending_callback, failure_callback
    response = send_preferences_request options

    if response.code != 201
      @errors << I18n.t(:mp_preferences_setup_error)
      raise MercadoPagoException.new
    end

    @preferences_response = ActiveSupport::JSON.decode(response)
  end

  def redirect_url
    point_key = sandbox ? 'sandbox_init_point' : 'init_point'
    @preferences_response[point_key] if @preferences_response.present?
  end

  def check_ipn_status(mercado_pago_id)
    response = send_notification_request mercado_pago_id
    if response
      payment = Spree::Payment.find_by id: response['collection']['external_reference']
      if payment
        check_status payment, response['collection']
      end
    end
  end

  def check_payment_status(payment)
    response = send_search_request({:external_reference => payment.id, :access_token => access_token})
    check_status payment, response['results'][0]['collection']
  end

  private

  def send_authentication_request
    RestClient.post(
        'https://api.mercadolibre.com/oauth/token',
        {:grant_type => 'client_credentials', :client_id => client_id, :client_secret => client_secret},
        :content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'
    )
  end

  def send_preferences_request(options)
    RestClient.post(
        preferences_url(access_token),
        options.to_json,
        :content_type => 'application/json', :accept => 'application/json'
    )
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

  # Check the payment state and update the order and payment state if required.
  #
  # If the payment status is 'approved', turn the order state to 'completed' and
  #   the payment state to 'paid'.
  # If the payment status is 'pending', 'in_process' or 'in_mediation'; turn the order state to 'completed' and
  #   the payment will become 'balance due' (or 'pending')
  # If the payment status is 'rejected', 'cancelled', 'refunded', turn the order state to 'completed' and
  #   the payment state to 'failure'.
  def check_status(payment, mp_response)
    status = mp_response['status']
    order = payment.order
    #TODO: Should 'complete' method call be out of case statement?
    case status
      when 'approved'
        order.next! unless order.complete?
        payment.purchase! unless order.paid?
      when 'pending', 'in_process', 'in_mediation'
        order.next! unless order.complete?
      when 'rejected', 'cancelled', 'refunded'
        order.next! unless order.complete?
        # Reload the payment instance because on order save it acquire another state
        # see https://github.com/spree/spree/blob/master/core/app/models/spree/order_updater.rb
        payment = order.payments.find(payment.id)
        payment.failure if payment.can_failure?
    end
  end

  def client_id
    @payment_method.preferred_client_id
  end

  def client_secret
    @payment_method.preferred_client_secret
  end

  def preferences_url(token)
    create_url 'https://api.mercadolibre.com/checkout/preferences', access_token: token
  end

  def sandbox
    @api_options[:sandbox]
  end

  def get(url, request_options={}, options={})
    begin
      response = RestClient.get(url, request_options)
      ActiveSupport::JSON.decode(response)
    rescue => e
      raise e unless options[:quiet]
    end
  end

  def create_preference_options(order, payment, success_callback,
      pending_callback, failure_callback)
    options = Hash.new
    options[:external_reference] = payment.id
    options[:back_urls] = {
        :success => success_callback,
        :pending => pending_callback,
        :failure => failure_callback
    }
    options[:items] = Array.new

    payer_options = @api_options[:payer]

    options[:payer] = payer_options if payer_options

    order.line_items.each do |li|
      h = {
          :title => line_item_description_text(li.variant.product.description),
          :unit_price => li.price.to_f,
          :quantity => li.quantity,
          :currency_id => 'ARS'
      }
      options[:items] << h

    end
    options
  end
end
