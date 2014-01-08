# -*- encoding : utf-8 -*-
require 'spec_helper'


shared_context 'logged user' do
  let(:user) { create(:user) }
  before(:each) do
    controller.stub(:spree_current_user => user)
    session[:order_id] = order.id
  end
end

shared_context 'another order' do
  let(:another_order) { Spree::Order.create(user: user, state: 'payment') }
  let(:another_payment) { create(:payment, payment_method: payment_method, order: order) }
end

describe Spree::MercadoPagoController do
  it "doesn't affect current order if there is one (session[:order_id])"

  context 'Logged out user' do
    it 'redirects to login and back again'
  end

  context 'Logged in user' do
    include_context 'logged user'
    before :each do
      WebMock.disable_net_connect!(:allow_localhost => true)
      stub_request(:post, 'https://api.mercadolibre.com/oauth/token').to_return(:status => 200, :body => {access_token: 123546}.to_json, :headers => {})
      stub_request(:get, "https://api.mercadolibre.com/sandbox/collections/search?access_token=123546&external_reference=#{payment.id}").
          with(:headers => {'Accept' => 'application/json', 'Accept-Encoding' => 'gzip, deflate', 'Content-Type' => 'application/x-www-form-urlencoded', 'User-Agent' => 'Ruby'}).
          to_return(:status => 200, :body => mercado_pago_seach_response.to_json, :headers => {})
    end

    let(:payment_method) { create(:payment_method, type: 'PaymentMethod::MercadoPago') }
    let(:order) { Spree::Order.create(user: user, state: 'payment') }
    let(:payment) { create(:payment, payment_method: payment_method, order: order) }
    let(:mercado_pago_seach_response) { {results: [{collection: {}}]} }
    let(:client) { double(:client) }

    describe '#success' do
      context 'spectate contributors calls' do
        before(:each) do
          allow(subject).to receive(:params).and_return(external_reference: payment.id)
          allow(subject).to receive(:current_order).and_return(order)
          allow(subject).to receive(:current_payment).and_return(payment)
          allow(client).to receive(:check_payment_status).and_return(payment)
        end

        it { expect(subject).to receive('create_client').and_return(client) }

        after(:each) do
          spree_get :success, {external_reference: payment.id}
        end

      end


      context 'with valid order' do

        before do
          spree_get :success, {external_reference: payment.id}
        end

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).should eq(order) }
        it { flash[:error].should be_nil }

      end
    end

    describe '#pending' do
      before :each do
        stub_request(:get, "https://api.mercadolibre.com/sandbox/collections/search?external_reference=#{another_payment.id}&access_token=123546&").
        with(:headers => {'Accept' => 'application/json', 'Accept-Encoding' => 'gzip, deflate', 'Content-Type' => 'application/x-www-form-urlencoded', 'User-Agent' => 'Ruby'}).
        to_return(:status => 200, :body => mercado_pago_seach_response.to_json, :headers => {})
        spree_get :pending, {external_reference: another_payment.id}
      end
      context 'with valid order' do
        include_context 'another order'

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).id.should eq(order.id) }
        it { flash[:error].should be_nil }
      end

      context 'with invalid order' do
        include_context 'another order'
        before do
          spree_get :success, {external_reference: another_payment.id}
        end
        before { spree_get :pending }

        it { response.should redirect_to(spree.root_path) }
        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end

    describe '#failure' do
      context 'with valid order' do
        before do
          spree_get :failure, {external_reference: payment.id}
        end

        it { response.should be_success }
        it { assigns(:current_order).should_not be_nil }
        it { assigns(:current_order).id.should eq(order.id) }
        it { assigns(:current_order).payment_state.should be_nil }
      end

      context 'with invalid order' do
        include_context 'another order'
        before { spree_get :failure, {external_reference: create(:payment, payment_method: payment_method, order: another_order).id} }

        it { flash[:error].should eq(I18n.t(:mp_invalid_order)) }
      end
    end
  end
end
