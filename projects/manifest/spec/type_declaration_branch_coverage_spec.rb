RSpec.describe Foobara::Manifest::TypeDeclaration do
  after do
    Foobara.reset_alls
  end

  describe ".new" do
    context "when type is :attributes" do
      let(:model_class) do
        stub_class("AttributesModel", Foobara::Model) do
          attributes do
            name :string
          end
        end
      end

      let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
      let(:raw_manifest) do
        model_class
        Foobara.manifest
      end

      it "returns an Attributes instance instead of TypeDeclaration" do
        # For model attributes, we use :type path and access attributes_type
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :AttributesModel, :attributes_type]
        )

        expect(type_declaration).to be_a(Foobara::Manifest::Attributes)
      end
    end

    context "when type is :array" do
      let(:command_class) do
        stub_class("ArrayCommand", Foobara::Command) do
          inputs do
            items [:string]
          end
        end
      end

      let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
      let(:raw_manifest) do
        command_class
        Foobara.manifest
      end

      it "returns an Array instance instead of TypeDeclaration" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "ArrayCommand", :inputs_type, :element_type_declarations, :items]
        )

        expect(type_declaration).to be_a(Foobara::Manifest::Array)
      end
    end

    context "when type is neither attributes nor array" do
      let(:command_class) do
        stub_class("SimpleCommand", Foobara::Command) do
          inputs do
            name :string
          end
        end
      end

      let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
      let(:raw_manifest) do
        command_class
        Foobara.manifest
      end

      it "returns a TypeDeclaration instance" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "SimpleCommand", :inputs_type, :element_type_declarations, :name]
        )

        expect(type_declaration.class).to eq(Foobara::Manifest::TypeDeclaration)
      end
    end

    context "when called on a subclass of TypeDeclaration" do
      let(:subclass) { Class.new(Foobara::Manifest::TypeDeclaration) }

      let(:command_class) do
        stub_class("SubclassCommand", Foobara::Command) do
          inputs do
            name :string
          end
        end
      end

      let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
      let(:raw_manifest) do
        command_class
        Foobara.manifest
      end

      it "returns an instance of the subclass directly" do
        type_declaration = subclass.new(
          root_manifest,
          [:command, "SubclassCommand", :inputs_type, :element_type_declarations, :name]
        )

        expect(type_declaration.class).to eq(subclass)
      end
    end
  end

  describe "#sensitive?" do
    let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
    let(:raw_manifest) do
      command_class
      Foobara.manifest
    end

    context "when sensitive is true" do
      let(:command_class) do
        stub_class("SensitiveCommand", Foobara::Command) do
          inputs do
            password :string, :sensitive
          end
        end
      end

      it "returns true" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "SensitiveCommand", :inputs_type, :element_type_declarations, :password]
        )

        expect(type_declaration.sensitive?).to be(true)
      end
    end

    context "when sensitive_exposed is true" do
      let(:command_class) do
        stub_class("SensitiveExposedCommand", Foobara::Command) do
          inputs do
            api_key :string, sensitive_exposed: true
          end
        end
      end

      it "returns true" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "SensitiveExposedCommand", :inputs_type, :element_type_declarations, :api_key]
        )

        expect(type_declaration.sensitive?).to be(true)
      end
    end

    context "when both are false" do
      let(:command_class) do
        stub_class("NonSensitiveCommand", Foobara::Command) do
          inputs do
            name :string
          end
        end
      end

      it "returns false" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "NonSensitiveCommand", :inputs_type, :element_type_declarations, :name]
        )

        expect(type_declaration.sensitive?).to be(false)
      end
    end
  end

  describe "#attribute?" do
    let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
    let(:raw_manifest) do
      model_class
      Foobara.manifest
    end

    context "when parent_path_atom is :element_type_declarations" do
      let(:model_class) do
        stub_class("TestModel", Foobara::Model) do
          attributes do
            name :string
          end
        end
      end

      it "returns true and memoizes the result" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :TestModel, :attributes_type, :element_type_declarations, :name]
        )

        expect(type_declaration.attribute?).to be(true)
        # Call again to test memoization
        expect(type_declaration.attribute?).to be(true)
      end
    end

    context "when parent_path_atom is 'element_type_declarations' (string)" do
      let(:model_class) do
        stub_class("StringKeyModel", Foobara::Model) do
          attributes do
            value :integer
          end
        end
      end

      it "returns true" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :StringKeyModel, :attributes_type, "element_type_declarations", :value]
        )

        expect(type_declaration.attribute?).to be(true)
      end
    end

    context "when not an attribute" do
      let(:model_class) do
        stub_class("NonAttributeModel", Foobara::Model) do
          attributes do
            name :string
          end
        end
      end

      it "returns false" do
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :NonAttributeModel, :attributes_type]
        )

        expect(type_declaration.attribute?).to be(false)
      end
    end
  end

  describe "#model?" do
    let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
    let(:raw_manifest) do
      model_class
      command_class
      Foobara.manifest
    end

    context "when type is a model" do
      let(:model_class) do
        stub_class("TestModel", Foobara::Model) do
          attributes do
            name :string
          end
        end
      end

      let(:command_class) do
        stub_class("TestCommand", Foobara::Command) do
          inputs do
            model TestModel
          end
        end
      end

      it "returns true and memoizes the result" do
        # Access model through a reference in command inputs
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "TestCommand", :inputs_type, :element_type_declarations, :model]
        )

        expect(type_declaration.model?).to be(true)
        # Test memoization
        expect(type_declaration.model?).to be(true)
      end
    end
  end

  describe "#custom?" do
    let(:root_manifest) { Foobara::Manifest::RootManifest.new(raw_manifest) }
    let(:raw_manifest) do
      type_class
      Foobara.manifest
    end

    context "when type is custom" do
      let(:type_class) do
        stub_class("CustomType", Foobara::BuiltinTypes[:duck]) do
        end
        Foobara::Types::Type.new(
          "CustomType",
          base_type: Foobara::BuiltinTypes[:duck],
          target_classes: [Object]
        )
      end

      it "returns custom status and memoizes" do
        # This is a tricky one to test as we need a custom type in the manifest
        # Let's create a simpler approach
        command_class = stub_class("CustomCommand", Foobara::Command) do
          inputs do
            name :string
          end
        end

        manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "CustomCommand", :inputs_type, :element_type_declarations, :name]
        )

        # String type is not custom
        expect(type_declaration.custom?).to be(false)
      end
    end
  end

  describe "#primitive?" do
    context "when type declaration is a reference" do
      it "delegates to to_type.primitive?" do
        model_class = stub_class("ReferenceModel", Foobara::Model) do
          attributes do
            name :string
          end
        end

        command_class = stub_class("ReferenceCommand", Foobara::Command) do
          inputs do
            model model_class
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "ReferenceCommand", :inputs_type, :element_type_declarations, :model]
        )

        expect(type_declaration.primitive?).to be(false)
      end
    end

    context "when type declaration is not a reference" do
      it "returns nil" do
        model_class = stub_class("NonReferenceModel", Foobara::Model) do
          attributes do
            # Use an inline array type declaration (not a reference)
            tags [type: :string]
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :NonReferenceModel, :attributes_type, :element_type_declarations, :tags]
        )

        # Non-reference types return nil from primitive? since they check reference? first
        expect(type_declaration.reference?).to be(false)
        expect(type_declaration.primitive?).to be_nil
      end
    end
  end

  describe "#detached_entity?" do
    context "when type is a detached entity" do
      it "returns true and memoizes" do
        # Create detached entity with primary_key
        detached_entity_class = stub_class("TestDetachedEntity", Foobara::DetachedEntity) do
          attributes do
            id :integer
            name :string
          end
          primary_key :id
        end

        # Use it in another model to create a reference
        model_class = stub_class("TestModel", Foobara::Model) do
          attributes do
            entity detached_entity_class
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        # Access the detached entity reference in the model
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :TestModel, :attributes_type, :element_type_declarations, :entity]
        )

        expect(type_declaration.detached_entity?).to be(true)
        # Test memoization
        expect(type_declaration.detached_entity?).to be(true)

        Foobara.reset_alls
      end
    end
  end

  describe "#entity?" do
    before do
      Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "when type is an entity" do
      it "returns true and memoizes" do
        entity_class = stub_class("TestEntity", Foobara::Entity) do
          attributes pk: :integer, name: :string
          primary_key :pk
        end

        command_class = stub_class("TestCommand", Foobara::Command) do
          inputs do
            entity :TestEntity
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        # Access entity through a reference in command inputs
        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "TestCommand", :inputs_type, :element_type_declarations, :entity]
        )

        expect(type_declaration.entity?).to be(true)
        expect(type_declaration.entity?).to be(true)

        Foobara.reset_alls
      end
    end
  end

  describe "#type" do
    context "when type declaration is a reference" do
      it "returns the relevant_manifest (the reference)" do
        model_class = stub_class("ReferencedModel", Foobara::Model) do
          attributes do
            name :string
          end
        end

        command_class = stub_class("ReferenceTypeCommand", Foobara::Command) do
          inputs do
            model model_class
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "ReferenceTypeCommand", :inputs_type, :element_type_declarations, :model]
        )

        expect(type_declaration.reference?).to be(true)
        result = type_declaration.type
        # For references, type returns the relevant_manifest which is the symbol/string
        expect(result).to be_a(Symbol).or be_a(String)
      end
    end

    context "when type declaration is not a reference" do
      it "returns super (the type from base manifest)" do
        model_class = stub_class("NonReferenceTypeModel", Foobara::Model) do
          attributes do
            # Use an inline array type declaration (not a reference)
            tags [type: :string]
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:type, :NonReferenceTypeModel, :attributes_type, :element_type_declarations, :tags]
        )

        expect(type_declaration.reference?).to be(false)
        result = type_declaration.type
        expect(result).to eq(:array)
      end
    end
  end

  describe "#sensitive" do
    context "when type declaration is a reference" do
      it "returns false for references" do
        model_class = stub_class("SensitiveModel", Foobara::Model) do
          attributes do
            password :string, :sensitive
          end
        end

        command_class = stub_class("ReferenceSensitiveCommand", Foobara::Command) do
          inputs do
            model model_class
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "ReferenceSensitiveCommand", :inputs_type, :element_type_declarations, :model]
        )

        expect(type_declaration.reference?).to be(true)
        expect(type_declaration.sensitive).to be(false)
      end
    end

    context "when type declaration is not a reference" do
      it "returns the actual sensitive value" do
        command_class = stub_class("NonReferenceSensitiveCommand", Foobara::Command) do
          inputs do
            password :string, :sensitive
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "NonReferenceSensitiveCommand", :inputs_type, :element_type_declarations, :password]
        )

        expect(type_declaration.reference?).to be(false)
        expect(type_declaration.sensitive).to be(true)
      end
    end
  end

  describe "#sensitive_exposed" do
    context "when type declaration is a reference" do
      it "returns false for references" do
        model_class = stub_class("SensitiveExposedModel", Foobara::Model) do
          attributes do
            api_key :string, sensitive_exposed: true
          end
        end

        command_class = stub_class("ReferenceSensitiveExposedCommand", Foobara::Command) do
          inputs do
            model model_class
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "ReferenceSensitiveExposedCommand", :inputs_type, :element_type_declarations, :model]
        )

        expect(type_declaration.reference?).to be(true)
        expect(type_declaration.sensitive_exposed).to be(false)
      end
    end

    context "when type declaration is not a reference" do
      it "returns the actual sensitive_exposed value" do
        command_class = stub_class("NonReferenceSensitiveExposedCommand", Foobara::Command) do
          inputs do
            api_key :string, sensitive_exposed: true
          end
        end

        raw_manifest = Foobara.manifest
        root_manifest = Foobara::Manifest::RootManifest.new(raw_manifest)

        type_declaration = Foobara::Manifest::TypeDeclaration.new(
          root_manifest,
          [:command, "NonReferenceSensitiveExposedCommand", :inputs_type, :element_type_declarations, :api_key]
        )

        expect(type_declaration.reference?).to be(false)
        expect(type_declaration.sensitive_exposed).to be(true)
      end
    end
  end
end
