require "mixlib/shellout"

require "spec_helper"

require_relative "../../fixtures/keystone_transaction"
require_relative "../../../libraries/pacemaker/transaction"

describe Pacemaker::Transaction do
  let(:transaction) { Chef::RSpec::Pacemaker::Config::KEYSTONE_TRANSACTION.dup }

  describe "#definition" do
    it "should return a multi-object configuration definition" do
      expect(transaction.definition).to \
        eq(Chef::RSpec::Pacemaker::Config::KEYSTONE_TRANSACTION_DEFINITION)
    end
  end
end
