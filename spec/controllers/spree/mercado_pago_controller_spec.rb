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


    before(:each) do
      controller.stub(:spree_current_user => user)
      session[:order_id] = order.id
    end

    let(:order) { Spree::Order.create(user: user, state: "payment") }
    let(:payment) {create(:payment, payment_method: payment_method, order: order)}
    let(:another_order) do
      order = Spree::Order.create(user: user, state: "payment")
      create(:payment, payment_method: payment_method, order: order)
      order
    end

    describe "#success" do
      context "with valid order" do

        before do
          spree_get :success, { external_reference: payment.id }
        end

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).state.should eq("complete") }
        it { assigns(:current_order).should eq(order)}
        it { assigns(:current_order).payment_state.should eq("paid") }
        it { flash[:error].should be_nil }

      end

      context "with invalid order" do
        before do
          spree_get :success, { external_reference: create(:payment, payment_method: payment_method, order: another_order).id }
        end


        it { response.should redirect_to(spree.root_path) }
        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end

    describe "#pending" do
      context "with valid order" do
        before do
          spree_get :pending, { external_reference: payment.id }
        end

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).state.should eq("complete") }
        it { assigns(:current_order).id.should eq(order.id)}
        it { assigns(:current_order).payment_state.should eq("balance_due") }
        it { flash[:error].should be_nil }
      end

      context "with invalid order" do
        before do
          spree_get :success, { external_reference: create(:payment, payment_method: payment_method, order: another_order).id }
        end
        before { spree_get :pending }

        it { response.should redirect_to(spree.root_path) }
        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end

    describe "#failure" do
      context "with valid order" do
        before do
          spree_get :failure, { external_reference: payment.id }
        end

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).state.should eq("payment") }
        it { assigns(:current_order).id.should eq(order.id)}
        it { assigns(:current_order).payment_state.should be_nil }
      end

      context "with invalid order" do
        before { spree_get :failure, { external_reference: create(:payment, payment_method: payment_method, order: another_order).id } }

        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end
  end
end
