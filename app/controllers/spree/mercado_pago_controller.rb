# -*- encoding : utf-8 -*-
module Spree

  class MercadoPagoController < Spree::StoreController

    before_filter :verify_external_reference, :current_payment, only: [:success, :pending]
    before_filter :payment_method_by_external_reference, :only => [:success, :pending, :failure]
    before_filter :verify_payment_state, :only => [:payment]
    skip_before_filter :verify_authenticity_token, :only => [:notification]

    # If the order is in 'payment' state, redirects to Mercado Pago Checkout page
    def payment
      mp_payment = current_order.payments.create! source: payment_method,
        amount: current_order.total,
        payment_method: @payment_method

      if create_preferences(mp_payment)
        redirect_to provider.redirect_url
      else
        render 'spree/checkout/mercado_pago_error'
      end
    end

    # "Mercado Pago" IPN
    def notification
      # TODO: FIXME. This is not the best way. What happens with multiples MercadoPago payments?
      @payment_method = ::PaymentMethod::MercadoPago.first
      external_reference = provider.get_external_reference params[:id]

      if external_reference
        payment = current_payment external_reference
        Resque.enqueue(PaymentStatusVerifier, payment.identifier) if payment
      end

      render status: :ok, nothing: true
    end

    def pending
      order.next! unless order.complete?
      Resque.enqueue(PaymentStatusVerifier, current_payment.identifier)
      render_result :pending
    end

    def success
      order.next! unless order.complete?
      Resque.enqueue(PaymentStatusVerifier, current_payment.identifier)
      render_result :success
    end

    def failure
      Resque.enqueue(PaymentStatusVerifier, current_payment.identifier)
      render_result :failure
    end

    private

    def create_preferences(mp_payment)
      preferences = create_preference_options(current_order, mp_payment, get_back_urls(mp_payment))

      Rails.logger.info "Sending preferences to MercadoPago"
      Rails.logger.info "#{preferences}"

      provider.create_preferences(preferences)
    end

    def create_preference_options(order, payment, callbacks)
      builder = MercadoPago::OrderPreferencesBuilder.new order, payment, callbacks, payer_data

      return builder.preferences_hash
    end


    def render_result(current_state)
      if success_order? and current_state != :success
        redirect_to_state :success
      end
      if failed_payment? and current_state != :failure
        redirect_to_state :failure
      end
      if pending_payment? and current_state != :pending
        redirect_to_state :pending
      end
    end

    def payment_method
      @payment_method ||= ::PaymentMethod::MercadoPago.find (params[:payment_method_id])
    end

    def provider
      @provider ||= payment_method.provider({:payer => payer_data})
    end

    def current_payment(payment_identifier=nil)
      payment_identifier ||= external_reference
      @current_payment ||= Spree::Payment.find_by identifier: payment_identifier
    end

    def success_order?
      current_payment.completed? and current_payment.order.completed?
    end

    def pending_payment?
      (current_payment.pending? || current_payment.processing?) and current_payment.order.completed?
    end

    def failed_payment?
      current_payment.failed? || current_payment.invalid?
    end

    def redirect_to_state(status)
      redirect_to controller: 'spree/mercado_pago', action: status, external_reference: external_reference
    end

    # Get payer info for sending within Mercado Pago request
    def payer_data
      email = get_email
      {email: email}
    end

    def external_reference
      if params[:external_reference] != "null"
        params[:external_reference]
      else
        params[:payment_identifier]
      end
    end

    # Get email for using in Mercado Pago request
    def get_email
      user = spree_current_user

      user.email if user
      current_order.email if current_order
    end

    # Get urls callbacks.
    # If the current 'payment method' haven't any callback, the default will be used
    def get_back_urls(mp_payment)
      success_url = payment_method.preferred_success_url
      pending_url = payment_method.preferred_pending_url
      failure_url = payment_method.preferred_failure_url

      get_params = {
        order_number: current_order.number,
        payment_identifier: mp_payment.identifier
      }

      success_url = spree.mercado_pago_success_url(get_params) if success_url.empty?
      pending_url = spree.mercado_pago_pending_url(get_params) if pending_url.empty?
      failure_url = spree.mercado_pago_failure_url(get_params) if failure_url.empty?

      {
          success: success_url,
          pending: pending_url,
          failure: failure_url,
      }
    end

    def verify_external_reference
      unless external_reference
        flash[:error] = I18n.t(:mp_invalid_order)
        redirect_to root_path
      end
    end

    def verify_payment_state
      redirect_to root_path unless current_order.payment?
    end

    def payment_method_by_external_reference
      @payment_method = current_payment.payment_method
    end
  end

end
