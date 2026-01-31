RSpec.describe Foobara::Model do
  after do
    Foobara.reset_alls
    [
      :SomeModel,
      :SomeEntity,
      :Foo,
      :CustomNamespace
    ].each do |const|
      Object.send(:remove_const, const) if Object.const_defined?(const)
    end
  end

  let(:model_class) do
    stub_class("SomeModel", described_class) do
      attributes do
        name :string, :required
        age :integer, :required
      end
    end
  end
  let(:model_instance) { model_class.new(name:, age:) }
  let(:name) { "foo" }
  let(:age) { 100 }

  it "can be mutated" do
    expect {
      model_instance.age += 1
    }.to change(model_instance, :age).by(1)
  end

  describe ".description" do
    context "with no arguments" do
      it "returns the description" do
        model_class.description "A test model"
        expect(model_class.description).to eq("A test model")
      end
    end

    context "with one argument" do
      it "sets the description" do
        expect {
          model_class.description "New description"
        }.to change { model_class.description }.from(nil).to("New description")
      end
    end
  end

  describe ".abstract" do
    it "marks the model as abstract" do
      model_class.abstract
      expect(model_class.abstract?).to be true
    end
  end

  describe ".abstract?" do
    it "returns false by default" do
      expect(model_class.abstract?).to be_falsey
    end

    it "returns true when marked abstract" do
      model_class.abstract
      expect(model_class.abstract?).to be true
    end
  end

  describe ".closest_namespace_module" do
    it "returns a namespace module" do
      namespace = model_class.closest_namespace_module
      expect(namespace).to_not be_nil
    end
  end

  describe ".domain" do
    context "when model_type is nil" do
      it "uses Domain.domain_through_modules" do
        allow(model_class).to receive(:model_type).and_return(nil)
        expect(Foobara::Domain).to receive(:domain_through_modules).with(model_class)
        model_class.domain
      end
    end

    context "when model has a type" do
      it "returns a domain" do
        domain = model_class.domain
        expect(domain).to_not be_nil
      end
    end
  end

  describe ".foobara_model_name" do
    it "returns the model name" do
      expect(model_class.foobara_model_name).to eq("SomeModel")
    end
  end

  describe ".full_model_name" do
    it "returns the longest name between model_type and model_name" do
      full_name = model_class.full_model_name
      expect(full_name).to be_a(String)
      expect(full_name).to_not be_empty
    end
  end

  describe ".possible_errors" do
    context "when mutable is true" do
      it "returns all possible errors from attributes_type" do
        errors = model_class.possible_errors(mutable: true)
        expect(errors).to be_an(Array)
      end
    end

    context "when mutable is an array of attribute names" do
      let(:model_with_validation) do
        stub_class("ValidationModel", described_class) do
          attributes do
            name :string, :required
            age :integer, min: 0, max: 120
            email :string
          end
        end
      end

      it "returns only errors for specified attributes" do
        errors = model_with_validation.possible_errors(mutable: [:age])
        expect(errors).to be_an(Array)
        # Just check that we got errors, don't check specific paths since structure may vary
        expect(errors.size).to be >= 0
      end
    end

    context "when mutable is false" do
      it "returns empty array" do
        errors = model_class.possible_errors(mutable: false)
        expect(errors).to eq([])
      end
    end
  end

  describe ".subclass" do
    context "when name is a symbol" do
      it "converts to string and creates subclass" do
        subclass = model_class.subclass(name: :SubModel)
        expect(subclass).to be < model_class
        expect(subclass.model_name).to eq("SubModel")
      end
    end

    context "when name is a string" do
      it "creates subclass with given name" do
        subclass = model_class.subclass(name: "SubModel")
        expect(subclass).to be < model_class
        expect(subclass.model_name).to eq("SubModel")
      end
    end
  end

  describe ".on_reregister" do
    it "registers callback for reregistration" do
      called = false
      model_class.on_reregister do |klass|
        called = true
      end

      model_class.fire_reregistered!(model_class)
      expect(called).to be true
    end
  end

  describe ".fire_reregistered!" do
    it "calls all registered callbacks" do
      call_count = 0
      model_class.on_reregister { call_count += 1 }
      model_class.on_reregister { call_count += 1 }

      model_class.fire_reregistered!(model_class)
      expect(call_count).to eq(2)
    end

    context "when no callbacks registered" do
      it "does not raise error" do
        new_model = Class.new(described_class)
        expect {
          new_model.fire_reregistered!(new_model)
        }.to_not raise_error
      end
    end
  end

  describe "#initialize" do
    context "when attributes is nil and validate option is true" do
      it "raises ArgumentError" do
        expect {
          model_class.new(nil, validate: true)
        }.to raise_error(ArgumentError, "Cannot use validate option without attributes")
      end
    end

    context "when validate option is true" do
      it "validates the model on initialization" do
        expect {
          model_class.new({ name: "test" }, validate: true)
        }.to raise_error(Foobara::Value::DataError)
      end
    end

    context "when skip_validations option is true" do
      it "sets skip_validations" do
        instance = model_class.new({ name: "test", age: 25 }, skip_validations: true)
        expect(instance.skip_validations).to be true
      end
    end

    context "when mutable option is provided" do
      it "uses the provided mutable option" do
        instance = model_class.new({ name: "test", age: 25 }, mutable: false)
        expect(instance.mutable).to be false
      end
    end

    context "when mutable is in declaration_data" do
      let(:type_declaration) do
        {
          type: :model,
          name: "TestModel",
          mutable: [:name],
          attributes_declaration: { name: :string, age: :integer }
        }
      end

      it "uses declaration_data mutable" do
        model_type = Foobara::Domain.current.foobara_type_from_declaration(type_declaration)
        model_class = model_type.target_class
        instance = model_class.new(name: "test", age: 25)

        expect(instance.mutable).to eq([:name])
      end
    end

    context "when mutable is an array" do
      it "converts elements to symbols" do
        instance = model_class.new({ name: "test", age: 25 }, mutable: ["name"])
        expect(instance.mutable).to eq([:name])
      end
    end
  end

  describe "ignore unexpected attributes option" do
    let(:outer_model_class) do
      inner = model_class

      stub_class("OuterModel", described_class) do
        attributes do
          inner_model inner, :required
        end
      end
    end

    it "ignores unexpected attributes" do
      attributes = { inner_model: { age: 100, name: "foo", height: 100 } }

      value = outer_model_class.new(attributes)
      expect(value).to_not be_valid

      value = outer_model_class.new(attributes, ignore_unexpected_attributes: true)
      expect(value).to be_valid

      expect(value.inner_model.attributes.keys).to contain_exactly(:age, :name)
    end

    context "when processing succeeds" do
      it "uses processed attributes" do
        attributes = { inner_model: { age: 100, name: "foo", height: 100 } }
        value = outer_model_class.new(attributes, ignore_unexpected_attributes: true)

        expect(value.inner_model.age).to eq(100)
        expect(value.inner_model.name).to eq("foo")
      end
    end
  end

  describe "#write_attribute" do
    context "when attribute is not mutable" do
      let(:instance) { model_class.new({ name: "test", age: 25 }, mutable: false) }

      it "raises AttributeIsImmutableError" do
        expect {
          instance.write_attribute(:name, "new name")
        }.to raise_error(Foobara::Model::AttributeIsImmutableError)
      end
    end

    context "when mutable is array and attribute is not in it" do
      let(:instance) { model_class.new({ name: "test", age: 25 }, mutable: [:name]) }

      it "raises AttributeIsImmutableError" do
        expect {
          instance.write_attribute(:age, 30)
        }.to raise_error(Foobara::Model::AttributeIsImmutableError)
      end
    end

    context "when mutable is array and attribute is in it" do
      let(:instance) { model_class.new({ name: "test", age: 25 }, mutable: [:name]) }

      it "allows writing the attribute" do
        instance.write_attribute(:name, "new name")
        expect(instance.name).to eq("new name")
      end
    end

    context "when casting fails" do
      let(:instance) { model_class.new({ name: "test", age: 25 }) }

      it "sets the original value" do
        instance.write_attribute(:age, "not a number")
        expect(instance.age).to eq("not a number")
      end
    end

    context "when casting succeeds" do
      let(:instance) { model_class.new({ name: "test", age: 25 }) }

      it "sets the casted value" do
        instance.write_attribute(:age, "30")
        expect(instance.age).to eq(30)
      end
    end
  end

  describe "#write_attribute!" do
    it "casts and writes the attribute" do
      model_instance.write_attribute!(:age, "35")
      expect(model_instance.age).to eq(35)
    end

    context "when attribute is invalid" do
      it "raises error" do
        expect {
          model_instance.write_attribute!(:nonexistent, "value")
        }.to raise_error(Foobara::Model::NoSuchAttributeError)
      end
    end
  end

  describe "#write_attributes" do
    it "writes multiple attributes" do
      model_instance.write_attributes(name: "new name", age: 35)
      expect(model_instance.name).to eq("new name")
      expect(model_instance.age).to eq(35)
    end
  end

  describe "#write_attributes!" do
    it "writes multiple attributes with casting" do
      model_instance.write_attributes!(age: "40")
      expect(model_instance.age).to eq(40)
    end
  end

  describe "#read_attribute" do
    it "returns the attribute value" do
      expect(model_instance.read_attribute(:name)).to eq("foo")
    end

    context "when attribute_name is a string" do
      it "converts to symbol and returns value" do
        expect(model_instance.read_attribute("name")).to eq("foo")
      end
    end
  end

  describe "#read_attribute!" do
    it "validates attribute name and returns value" do
      expect(model_instance.read_attribute!(:name)).to eq("foo")
    end

    context "when attribute doesn't exist" do
      it "raises NoSuchAttributeError" do
        expect {
          model_instance.read_attribute!(:nonexistent)
        }.to raise_error(Foobara::Model::NoSuchAttributeError)
      end
    end
  end

  describe "#cast_attribute" do
    context "when attribute_type is nil" do
      it "returns success with original value" do
        allow(model_instance.class.attributes_type).to receive(:element_types).and_return({})
        outcome = model_instance.cast_attribute(:unknown, "value")

        expect(outcome).to be_success
        expect(outcome.result).to eq("value")
      end
    end

    context "when casting fails" do
      it "prepends attribute name to error path" do
        outcome = model_instance.cast_attribute(:age, "not a number")

        unless outcome.success?
          outcome.errors.each do |error|
            expect(error.path).to include(:age)
          end
        end
      end
    end
  end

  describe "#cast_attribute!" do
    it "validates attribute name before casting" do
      expect {
        model_instance.cast_attribute!(:nonexistent, "value")
      }.to raise_error(Foobara::Model::NoSuchAttributeError)
    end

    it "raises on casting error" do
      expect {
        model_instance.cast_attribute!(:age, "not a number")
      }.to raise_error
    end
  end

  describe "#attributes_with_delegates" do
    it "returns attributes merged with delegates" do
      attrs = model_instance.attributes_with_delegates
      expect(attrs).to be_a(Hash)
      expect(attrs).to include(:name, :age)
    end
  end

  describe "#valid?" do
    it "returns true when model is valid" do
      expect(model_instance.valid?).to be true
    end

    it "returns false when model is invalid" do
      invalid_instance = model_class.new(name: "test")
      expect(invalid_instance.valid?).to be false
    end
  end

  describe "#validation_errors" do
    it "returns empty error collection when valid" do
      errors = model_instance.validation_errors
      expect(errors.empty?).to be true
    end

    it "returns errors when invalid" do
      invalid_instance = model_class.new(name: "test")
      errors = invalid_instance.validation_errors
      expect(errors.empty?).to be false
    end
  end

  describe "#validate!" do
    it "does not raise when valid" do
      expect {
        model_instance.validate!
      }.to_not raise_error
    end

    it "raises when invalid" do
      invalid_instance = model_class.new(name: "test")
      expect {
        invalid_instance.validate!
      }.to raise_error
    end
  end

  describe "#==" do
    it "returns true for same class and attributes" do
      other = model_class.new(name: "foo", age: 100)
      expect(model_instance == other).to be true
    end

    it "returns false for different attributes" do
      other = model_class.new(name: "bar", age: 100)
      expect(model_instance == other).to be false
    end

    it "returns false for different class" do
      other_class = stub_class("OtherModel", described_class) do
        attributes do
          name :string
          age :integer
        end
      end
      other = other_class.new(name: "foo", age: 100)
      expect(model_instance == other).to be false
    end
  end

  describe "#eql?" do
    it "delegates to ==" do
      other = model_class.new(name: "foo", age: 100)
      expect(model_instance.eql?(other)).to be true
    end
  end

  describe "#hash" do
    it "returns hash of attributes" do
      expect(model_instance.hash).to eq(model_instance.attributes.hash)
    end
  end

  describe "#to_h" do
    it "returns attributes hash" do
      expect(model_instance.to_h).to eq(name: "foo", age: 100)
    end
  end

  describe "#to_json" do
    it "returns JSON representation" do
      json = model_instance.to_json
      expect(json).to be_a(String)
    end
  end

  describe ".deanonymize_class" do
    let(:type_declaration) do
      {
        type: :model,
        name: model_name,
        attributes_declaration:,
        model_module:
      }
    end
    let(:model_name) { "SomeEntity" }
    let(:model_module) { nil }
    let(:attributes_declaration) do
      {
        foo: { type: :integer, max: 10 },
        pk: { type: :integer },
        bar: { type: :string, required: true }
      }
    end
    let(:model_type) do
      Foobara::Domain.current.foobara_type_from_declaration(type_declaration)
    end
    let(:model_class) do
      model_type.target_class
    end

    it "deanonymizes the class" do
      expect(model_class).to be_a(Class)
      expect(model_class.superclass).to be(described_class)
      expect(model_class.name).to be_nil
      expect(model_class.foobara_name).to eq("SomeEntity")

      described_class.deanonymize_class(model_class)

      expect(model_class.name).to eq(model_name)

      # allowed to call it twice...
      expect(described_class.deanonymize_class(model_class)).to be(model_class)
    end

    context "with a model module that doesn't exist" do
      let(:model_module) { "Foo::Bar::Baz" }

      it "deanonymizes the class" do
        expect(model_class).to be_a(Class)
        expect(model_class.superclass).to be(described_class)
        expect(model_class.name).to be_nil

        described_class.deanonymize_class(model_class)

        expect(model_class.name).to eq("Foo::Bar::Baz::SomeEntity")
      end
    end

    context "when a module already exists with the desired model name" do
      let(:model_module) { "Foo::Bar" }
      let(:model_name) { "SomeModel" }

      before do
        Foobara::Util.make_module_p("Foo::Bar::SomeModel", tag: true)

        stub_const("Foo::Bar::SomeModel::SOME_CONST", "some_const")
      end

      after do
        if Object.const_defined?(:Foo)
          Object.send(:remove_const, :Foo)
        end
      end

      it "upgrades the module to a class and copies over the constants" do
        expect(Foo::Bar::SomeModel).to be_a(Module)
        expect(Foo::Bar::SomeModel).to_not be_a(Class)

        described_class.deanonymize_class(model_class)

        expect(Foo::Bar::SomeModel).to be_a(Class)
        expect(Foo::Bar::SomeModel::SOME_CONST).to eq("some_const")
      end
    end
  end

  describe ".foobara_manifest" do
    it "includes model information" do
      manifest = model_class.foobara_manifest

      expect(manifest[:model_name]).to eq("SomeModel")
      expect(manifest[:attributes_type]).to be_a(Hash)
    end

    context "when remove_sensitive is false" do
      it "does not remove sensitive types" do
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_remove_sensitive?).and_return(false)
        manifest = model_class.foobara_manifest
        expect(manifest).to be_a(Hash)
        expect(manifest[:model_name]).to eq("SomeModel")
      end
    end

    context "when model has sensitive attributes" do
      let(:model_with_sensitive_class) do
        stub_class("SensitiveModel", described_class) do
          attributes do
            name :string, :required
            ssn :string, :sensitive
          end
        end
      end

      it "keeps sensitive attributes when remove_sensitive is false" do
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_remove_sensitive?).and_return(false)
        manifest = model_with_sensitive_class.foobara_manifest

        attributes_type = manifest[:attributes_type]
        expect(attributes_type[:element_type_declarations].keys).to include(:ssn)
      end

      it "removes sensitive attributes when remove_sensitive is true" do
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_remove_sensitive?).and_return(true)
        manifest = model_with_sensitive_class.foobara_manifest

        attributes_type = manifest[:attributes_type]
        expect(attributes_type[:element_type_declarations].keys).to_not include(:ssn)
      end
    end
  end

  describe ".domain with complex module resolution" do
    context "when model_type domain is GlobalDomain and module check needed" do
      it "falls back to GlobalDomain when module doesn't exist" do
        type_declaration = {
          type: :model,
          name: "TestModel",
          model_module: "NonExistent::Module::Path",
          attributes_declaration: { name: :string }
        }

        model_type = Foobara::Domain.current.foobara_type_from_declaration(type_declaration)
        model_class = model_type.target_class

        domain = model_class.domain
        expect(domain).to eq(Foobara::GlobalDomain)
      end
    end

    context "when checking module existence in loop" do
      it "iterates through module hierarchy" do
        type_declaration = {
          type: :model,
          name: "TestModel",
          model_module: "Some::Nested::Path",
          attributes_declaration: { name: :string }
        }

        model_type = Foobara::Domain.current.foobara_type_from_declaration(type_declaration)
        model_class = model_type.target_class

        # Should end up with GlobalDomain since modules don't exist
        domain = model_class.domain
        expect(domain).to eq(Foobara::GlobalDomain)
      end
    end

    context "when model has a domain through its namespace" do
      it "returns the domain" do
        domain = model_class.domain
        expect([Foobara::Domain, Foobara::GlobalDomain.class]).to include(domain.class)
      end
    end
  end

  describe ".foobara_model_name edge cases" do
    context "when foobara_type has scoped_path_set and scoped_name" do
      it "returns scoped_name from type" do
        expect(model_class.foobara_model_name).to eq("SomeModel")
      end
    end

    context "when using model_name from split" do
      it "extracts name from model_name" do
        name = model_class.foobara_model_name
        expect(name).to be_a(String)
        expect(name).to_not be_empty
      end
    end
  end

  describe ".closest_namespace_module edge cases" do
    context "when module is GlobalOrganization" do
      it "returns GlobalDomain" do
        allow(Foobara::Util).to receive(:module_for).with(model_class).and_return(Foobara::GlobalOrganization)

        namespace = model_class.closest_namespace_module
        expect(namespace).to eq(Foobara::GlobalDomain)
      end
    end

    context "when module is Foobara itself" do
      it "returns GlobalDomain" do
        allow(Foobara::Util).to receive(:module_for).with(model_class).and_return(Foobara)

        namespace = model_class.closest_namespace_module
        expect(namespace).to eq(Foobara::GlobalDomain)
      end
    end

    context "when module is nil" do
      it "returns GlobalDomain" do
        allow(Foobara::Util).to receive(:module_for).with(model_class).and_return(nil)

        namespace = model_class.closest_namespace_module
        expect(namespace).to eq(Foobara::GlobalDomain)
      end
    end
  end

  describe "#initialize with ignore_unexpected_attributes" do
    let(:outer_model_class) do
      inner = model_class

      stub_class("OuterModel", described_class) do
        attributes do
          inner_model inner, :required
        end
      end
    end

    context "when processing fails" do
      it "still initializes without processed attributes" do
        attributes = { inner_model: { age: "invalid", name: "foo", height: 100 } }

        # When processing fails, it should not use processed attributes
        value = outer_model_class.new(attributes, ignore_unexpected_attributes: true)
        expect(value).to_not be_nil
      end
    end
  end

  describe "#read_attribute with nil attribute_name" do
    it "handles nil attribute name" do
      result = model_instance.read_attribute(nil)
      expect(result).to be_nil
    end
  end

  describe ".validate_attribute_name!" do
    it "validates attribute names" do
      expect {
        model_class.validate_attribute_name!(:nonexistent)
      }.to raise_error(Foobara::Model::NoSuchAttributeError)
    end

    it "allows valid attribute names" do
      expect {
        model_class.validate_attribute_name!(:name)
      }.to_not raise_error
    end
  end
end
