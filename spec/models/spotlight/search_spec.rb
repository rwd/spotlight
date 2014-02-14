require 'spec_helper'

describe Spotlight::Search do

  before do
    subject.query_params = {"f"=>{"genre_sim"=>["map"]}}
  end

  it "should have a default feature image" do
    subject.stub(images: [['title', 'image_url'], ['title1', 'image2']])
    subject.save
    expect(subject.featured_image).to eq 'image_url'
  end

  it "should have items" do
    expect(subject.count).to eq 246
  end

  it "should have images" do
    expect(subject.images.size).to eq 246
    expect(subject.images.map(&:last)).to include "https://stacks.stanford.edu/image/pz918yt4565/AM_0425_thumb", "https://stacks.stanford.edu/image/rg099nx3058/AM_0429_thumb"
  end

  describe "default_scope" do
    let!(:page1) { FactoryGirl.create(:search, weight: 5) }
    let!(:page2) { FactoryGirl.create(:search, weight: 1) }
    let!(:page3) { FactoryGirl.create(:search, weight: 10) }
    it "should order by weight" do
      expect(Spotlight::Search.all.map(&:weight)).to eq [1, 5, 10]
    end
  end
end
