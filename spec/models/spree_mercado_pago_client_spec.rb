# -*- encoding : utf-8 -*-
require 'spec_helper'

describe SpreeMercadoPagoClient do
  SPEC_ROOT = File.expand_path("../", File.dirname(__FILE__))

  let(:payment_method) do
    double(
      "payment_method",
      :preferred_client_id => 1,
      :preferred_client_secret => 1
    )
  end


  let(:order) { double("order", :payment_method => payment_method, :number => "testorder", :line_items => []) }
  let(:url_callbacks) { {success: "url", failure: "url", pending: "url"} }
  
  let(:payment_method) { double :payment_method, id: 1, preferred_client_id:"app id", preferred_client_secret: "app secret" }
  let(:payment) {double :payment, payment_method:payment_method, id:1 }
  let(:login_json_response)  do
    File.open("#{SPEC_ROOT}/fixtures/authenticated.json", "r").read
  end

  let(:preferences_json_response) do
    File.open("#{SPEC_ROOT}/fixtures/preferences_created.json", "r").read
  end

  let(:client) {SpreeMercadoPagoClient.new(order, payment, url_callbacks[:success], url_callbacks[:pending], url_callbacks[:failure] )}

  describe "#initialize" do

    it "doesn't raise error with all params" do
      expect {client}.not_to raise_error
    end
  end

  describe "#authenticate" do
    context "On success" do
      let(:http_response) {
        response = double("response")
        response.stub(:code) { 200 }
        response.stub(:to_str) { login_json_response }
        response
        }
      let(:js_response) {ActiveSupport::JSON.decode(http_response)}
      before(:each) do
        expect(RestClient).to receive(:post).and_return( http_response )
      end

      it "returns a response object" do
        expect(client.authenticate).to eq(js_response)
      end

      it "#errors returns empty array" do
        client.authenticate
        client.errors.should be_empty
      end

      it "sets the access token" do
        client.authenticate
        client.auth_response["access_token"].should eq("TU_ACCESS_TOKEN")
      end
    end

    context "On failure" do
      let(:bad_request_response) do
        response = double("response")
        response.stub(:code) { 400 }
        response.stub(:to_str) { "" }
        response
      end

      before { RestClient.should_receive(:post) { bad_request_response } }

      it "raise exception on invalid authentication" do
        expect { client.authenticate }.to raise_error(MercadoPagoException) do |error|
          client.errors.should include(I18n.t(:mp_authentication_error))
        end
      end
    end
  end

  describe "#send_data" do

    context "On success" do
      before(:each) do
        response = double("response")
        response.stub(:code).and_return(200, 201)
        response.stub(:to_str).and_return(login_json_response, preferences_json_response)
        RestClient.should_receive(:post).exactly(2).times { response }

        client.authenticate
      end

      it "return value should not be nil" do
        client.send_data.should_not be_nil
      end

      it "#redirect_url returns offsite checkout url" do
        client.send_data
        client.redirect_url.should be_present
        client.redirect_url.should eq("https://www.mercadopago.com/checkout/pay?pref_id=identificador_de_la_preferencia")
      end
    end

    context "on failure" do
      before(:each) do

        response = double("response")
        response.stub(:code).and_return(200, 400)
        response.stub(:to_str) { {some_fake_data: "irrelevant"}.to_json }
        RestClient.should_receive(:post).exactly(2).times { response }
        client.authenticate
      end

      it "throws exception and populate errors" do
        expect {client.send_data}.to raise_error(MercadoPagoException) do |variable|
          client.errors.should include(I18n.t(:mp_authentication_error))
        end
      end

    end
  end

end
