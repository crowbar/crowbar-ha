# Shared code used to test subclasses of Pacemaker::CIBObject

require_relative "../../libraries/pacemaker/cib_object"
require_relative "crm_mocks"

shared_examples "a CIB object" do
  include Chef::RSpec::Pacemaker::Mocks

  def expect_to_match_fixture(obj)
    expect(obj.class).to eq(pacemaker_object_class)
    fields.each do |field|
      method = field.to_sym
      expect(obj.send(method)).to eq(fixture.send(method))
    end
  end

  it "should be instantiated via Pacemaker::CIBObject.from_name" do
    mock_existing_cib_object_from_fixture(fixture)
    obj = Pacemaker::CIBObject.from_name(fixture.name)
    expect_to_match_fixture(obj)
  end

  it "should instantiate by parsing a definition" do
    obj = Pacemaker::CIBObject.from_definition(fixture.definition_string)
    expect_to_match_fixture(obj)
  end

  it "should barf if the loaded definition's type is not right" do
    mock_existing_cib_object(fixture.name, "sometype #{fixture.name} blah blah")
    expect { fixture.load_definition }.to \
      raise_error(Pacemaker::CIBObject::TypeMismatch,
                  "Expected #{object_type} type but loaded definition was type sometype")
  end
end
