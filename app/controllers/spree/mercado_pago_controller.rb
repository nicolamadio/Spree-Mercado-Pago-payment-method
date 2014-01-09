# -*- encoding : utf-8 -*-
require 'rest_client'

module Spree
  class MercadoPagoController < Spree::StoreController
    before_filter :verify_external_reference, :current_payment, only: [:success, :pending]
    before_filter :payment_method_by_external_reference, :only => [:success, :pending, :failure]
    before_filter :verify_payment_state, :only => [:payment]
    skip_before_filter :verify_authenticity_token, :only => [:notification]

    # Callback for "Mercado Pago". Check the order status
    def success
      result
    end

    # Callback for "Mercado Pago". Check the order status
    def pending
      result
    end

    def result
      mercado_pago_client = create_client
      mercado_pago_client.check_payment_status current_payment
      if current_payment.state_name == :completed
        render :success
      else
        render :pending
      end
    end

    # Callback for "Mercado Pago".
    def failure
      current_order
      flash[:error] = I18n.t(:mp_invalid_order)
    end

    # If the order is in 'payment' state, redirects to Mercado Pago Checkout page
    def payment
      @payment_method = Spree::PaymentMethod.find(params[:payment_method_id])

      @mp_payment = current_order.payments.create!({:source => @payment_method, :amount => current_order.total, :payment_method => @payment_method})

      mercado_pago_client = create_client
      back_urls = get_back_urls

      if mercado_pago_client.authenticate && mercado_pago_client.create_preference(@current_order, @mp_payment, back_urls[:success], back_urls[:pending], back_urls[:failure])
        redirect_to mercado_pago_client.redirect_url
      else
        render :action => 'spree/checkout/mercado_pago_error'
      end

    end

    # The current payment find through Spree::Payment.find(params[:external_reference])
    # Maybe it has a security problem.
    def current_payment
      @current_payment = Spree::Payment.find(params[:external_reference]) unless @current_payment
      @current_payment
    end

    def notification
      # TODO: FIXME. This is not the best way. What happens with multiples MercadoPago payments?
      # Maybe the client shouldn't have the payment_method as required param
      @payment_method = ::PaymentMethod::MercadoPago.first
      mercado_pago_client = create_client
      mercado_pago_client.authenticate
      mercado_pago_client.check_ipn_status params[:id]

      render status: :ok, nothing: true
    end

    private

    # creates and returns a Mercado Pago client
    def create_client
      options = {
          sandbox: @payment_method.preferred_sandbox
      }
      options[:payer] = payer_data
      SpreeMercadoPagoClient.new(@payment_method, options)
    end

    # Get payer info for sending within Mercado Pago request
    def payer_data
      email = get_email
      {email: email}
    end

    # Get email for using in Mercado Pago request
    def get_email
      user = spree_current_user

      user.email if user
      current_order.email if current_order
    end

    # Get urls callbacks.
    # If the current 'payment method' haven't any callback, the default will be used
    def get_back_urls
      success_url = @payment_method.preferred_success_url
      pending_url = @payment_method.preferred_pending_url
      failure_url = @payment_method.preferred_failure_url

      success_url = spree.mercado_pago_success_url(order_number: @current_order.number) if success_url.empty?
      pending_url = spree.mercado_pago_pending_url(order_number: @current_order.number) if pending_url.empty?
      failure_url = spree.mercado_pago_failure_url(order_number: @current_order.number) if failure_url.empty?

      {
          success: success_url,
          pending: pending_url,
          failure: failure_url,
      }
    end

    def verify_external_reference
      external_reference = params[:external_reference]
      unless external_reference
        flash[:error] = I18n.t(:mp_invalid_order)
        redirect_to root_path
      end
    end

    def verify_payment_state
      redirect_to root_path unless current_order.payment?
    end

    def payment_method_by_external_reference
      external_reference = params[:external_reference]
      @payment_method = Spree::Payment.find(external_reference).payment_method
    end
  end
end
