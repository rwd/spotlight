require 'spec_helper'

describe Spotlight::SolrController, type: :controller do
  routes { Spotlight::Engine.routes }
  let(:exhibit) { FactoryGirl.create(:exhibit) }

  describe 'when user does not have access' do
    before { sign_in FactoryGirl.create(:exhibit_visitor) }
    it 'does not allow update' do
      post :update, exhibit_id: exhibit
      expect(response).to redirect_to main_app.root_path
    end
  end

  describe 'when user is an admin' do
    let(:admin) { FactoryGirl.create(:site_admin) }
    let(:role) { admin.roles.first }
    let(:solr) { double }
    before { sign_in admin }
    before do
      expect(controller).to receive(:blacklight_solr).and_return(solr)
    end

    it 'passes through the request data' do
      doc = {}
      expect(solr).to receive(:update) do |arr|
        doc = arr.first
      end

      post :update, { a: 1 }.to_json, content_type: :json, exhibit_id: exhibit

      expect(response).to be_successful
      expect(doc).to include 'a' => 1
    end

    it 'enriches the request with exhibit solr data' do
      doc = {}
      expect(solr).to receive(:update) do |arr|
        doc = arr.first
      end

      post :update, { a: 1 }.to_json, content_type: :json, exhibit_id: exhibit

      expect(response).to be_successful
      expect(doc).to include exhibit.solr_data
    end

    it 'enriches the request with sidecar data' do
      doc = {}
      expect(solr).to receive(:update) do |arr|
        doc = arr.first
      end

      allow_any_instance_of(SolrDocument).to receive(:to_solr).and_return(b: 1)

      post :update, { a: 1 }.to_json, content_type: :json, exhibit_id: exhibit

      expect(response).to be_successful
      expect(doc).to include b: 1
    end
  end
end
