require "mixlib/shellout"

require "spec_helper"

require_relative "../../../libraries/pacemaker/resource"
require_relative "../../fixtures/keystone_primitive"

describe Pacemaker::Resource do
  describe "#running?" do
    let(:rsc) { Pacemaker::Resource.new("keystone") }

    before(:each) do
      @cmd = double(Mixlib::ShellOut)
      expect(rsc).to receive(:shell_out!) \
        .with(*%w(crm resource status keystone)) \
        .and_return(@cmd)
    end

    it "should return true" do
      expect(@cmd).to receive(:stdout).at_least(:once) \
        .and_return("resource #{rsc.name} is running on: d52-54-00-e5-6b-a0")
      expect(rsc.running?).to be_true
    end

    it "should return false" do
      expect(@cmd).to receive(:stdout).at_least(:once) \
        .and_return("resource #{rsc.name} is NOT running")
      expect(rsc.running?).to be_false
    end
  end

  describe "::extract_hash" do
    let(:fixture) { Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE.dup }

    it "should extract a params hash from config" do
      expect(fixture.class.extract_hash(fixture.definition_string, "params")).to \
        eq(Hash[fixture.params])
    end

    it "should extract an op start hash from config" do
      expect(fixture.class.extract_hash(fixture.definition_string, "op start")).to \
        eq(Hash[fixture.op]["start"])
    end

    it "should extract an op monitor hash from config" do
      expect(fixture.class.extract_hash(fixture.definition_string, "op monitor")).to \
        eq(Hash[fixture.op]["monitor"])
    end

    it "should extract an op monitor hash from config" do
      expect(fixture.class.extract_hash(fixture.definition_string, "meta")).to \
        eq(Hash[fixture.meta])
    end

    it "should handle an empty meta section gracefully" do
      no_meta = fixture.definition_string.gsub(/\bmeta .*\\$/, "meta \\")
      expect(fixture.class.extract_hash(no_meta, "meta")).to eq({})
    end
  end
end
