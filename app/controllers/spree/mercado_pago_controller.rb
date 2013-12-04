# -*- encoding : utf-8 -*-
require 'rest_client'

module Spree
  class MercadoPagoController < Spree::StoreController
    before_filter :current_order, :check_order_state, :check_payment_state, :current_payment, only: [:success, :pending,]
    before_filter :get_payment_method, :create_payment, only: [:payment, :checkout_options]

    # Callback for "Mercado Pago". Set the order as "complete" and its payment as "paid"
    # TODO: Check payment state against Mercado Pago IPN
    def success
      @current_order.next!
      @current_payment.purchase!
    end

    # Callback for "Mercado Pago". Set the order as "complete" and its payment as "balance_due"
    # TODO: Check payment state against Mercado Pago IPN
    def pending
      @current_order.next!
    end

    # Callback for "Mercado Pago".
    # TODO: define what to do with Payment state
    def failure
      current_order
      flash[:error] = I18n.t(:mp_invalid_order)
    end

    # If the order is in 'payment' state, redirects to Mercado Pago Checkout page
    def payment
      return unless current_order.payment?

      mercado_pago_client = create_client

      if mercado_pago_client.authenticate && mercado_pago_client.send_data
        redirect_to mercado_pago_client.redirect_url
      else
        render :action => 'spree/checkout/mercado_pago_error'
      end

    end

    def checkout_options
      return unless current_order.payment?

      mercado_pago_client = create_client

      if mercado_pago_client.authenticate && mercado_pago_client.send_data
        render json: {
            url: mercado_pago_client.redirect_url,
            mode: mercado_pago_client.mode
        }
      end
    end

    # The current payment find through order.payments.find(id)
    # Used for supporting only (in specs mainly)
    def current_payment
      @current_payment = current_order.payments.find(params[:external_reference]) unless @current_payment
      @current_payment
    end

    private

    # creates and returns a Mercado Pago client
    # TODO: Refactor
    def create_client
      back_urls = get_back_urls
      options = {
          sandbox: @payment_method.preferred_sandbox,
          payment: @mp_payment
      }
      options[:payer] = payer_data
      SpreeMercadoPagoClient.new(@current_order, @mp_payment, back_urls[:success], back_urls[:pending], back_urls[:failure], options)
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
      current_order.email
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

    # Check the right state of order state
    def check_order_state
      check_state { current_order.payment? }
    end

    # Check the right state of order payment state
    def check_payment_state
      check_state { @current_order.payments.where(id: params[:external_reference]).exists? }
    end

    def check_state
      unless yield
        flash[:error] = I18n.t(:mp_invalid_order)
        redirect_to root_path
      end
    end

    def create_payment
      @mp_payment = current_order.payments.create!({:source => @payment_method, :amount => @current_order.total, :payment_method => @payment_method})
    end

    def get_payment_method
      selected_method_id = params[:payment_method_id]
      @payment_method = Spree::PaymentMethod.find(selected_method_id)
    end
  end
end
