# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Spree::MercadoPagoController do
  it "doesn't affect current order if there is one (session[:order_id])"

  context "Logged out user" do
    it "redirects to login and back again"
  end

  context "Logged in user" do
    let(:user)           { create(:user) }
    let(:payment_method) { create(:payment_method, type: "PaymentMethod::MercadoPago") }


    before { controller.stub(:spree_current_user => user) }
    #before do
    #  order.payment.should_not be_nil
    #  order.payment_method.should_not be_nil
    #  order.payment_method.type.should eq("PaymentMethod::MercadoPago")
    #end

    describe "#success" do

      let(:order) do
        order = Spree::Order.create(user: user, state: "payment")
        session[:order_id] = order.id
        create(:payment, payment_method: payment_method, order: order)
        order
      end

      context "with valid order" do
        before do
          spree_get :success, { external_reference: order.payments.last }
        end

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).state.should eq("complete") }
        it { assigns(:current_order).id.should eq(order.id)}
        it { assigns(:current_order).payment_state.should eq("paid") }
      end

      context "with invalid order" do
        let(:another_order) do
          order = Spree::Order.create(user: user, state: "payment")
          session[:order_id] = order.id
          create(:payment, payment_method: payment_method, order: order)
          order
        end
        before do
          spree_get :success, { external_reference: create(:payment, payment_method: payment_method, order: another_order) }
        end


        it { response.should redirect_to(spree.root_path) }
        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end

    describe "#pending" do
      context "with valid order" do
        before do
          spree_get :pending, { order_number: order.number }
        end

        it { response.should be_success }
        it { assigns(:order).should_not be_nil }
        it { assigns(:order).state.should eq("complete") }
        it { assigns(:order).id.should eq(order.id)}
        it { assigns(:order).payment.state.should eq("pending") }
      end

      context "with invalid order" do
        before { spree_get :pending }

        it { response.should redirect_to(spree.root_path) }
        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end

    describe "#failure" do
      context "with valid order" do
        before do
          spree_get :failure, { order_number: order.number }
        end

        it { response.should be_success }
        it { assigns(:order).should_not be_nil }
        it { assigns(:order).state.should eq("payment") }
        it { assigns(:order).id.should eq(order.id)}
        it { assigns(:order).payment.state.should eq("pending") }
      end

      context "with invalid order" do
        before { spree_get :failure }

        it { response.should redirect_to(spree.root_path) }
        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end
  end
end
