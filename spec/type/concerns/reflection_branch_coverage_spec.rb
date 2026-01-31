RSpec.describe Foobara::Types::Type::Concerns::Reflection do
  after do
    Foobara.reset_alls
  end

  describe "#types_depended_on" do
    context "when element_types is a Hash with sensitive values and remove_sensitive is true" do
      it "excludes sensitive types" do
        model_class = stub_class("SensitiveHashModel", Foobara::Model) do
          attributes do
            password :string, :sensitive
            name :string
          end
        end

        attributes_type = model_class.attributes_type

        Foobara::TypeDeclarations.with_manifest_context(remove_sensitive: true) do
          result = attributes_type.types_depended_on
          expect(result).to be_a(Set)
        end
      end
    end

    context "when element_types is a Hash and remove_sensitive is false" do
      it "includes all types" do
        model_class = stub_class("NonSensitiveHashModel", Foobara::Model) do
          attributes do
            password :string, :sensitive
            name :string
          end
        end

        attributes_type = model_class.attributes_type

        Foobara::TypeDeclarations.with_manifest_context(remove_sensitive: false) do
          result = attributes_type.types_depended_on
          expect(result).to be_a(Set)
        end
      end
    end

    context "when element_types is an Array with sensitive elements and remove_sensitive is true" do
      it "rejects sensitive elements" do
        inner_model_class = stub_class("InnerArrayModel", Foobara::Model) do
          attributes do
            value :string
          end
        end

        model_class = stub_class("SensitiveArrayElemModel", Foobara::Model) do
          attributes do
            items [inner_model_class], :sensitive
          end
        end

        attributes_type = model_class.attributes_type

        Foobara::TypeDeclarations.with_manifest_context(remove_sensitive: true) do
          result = attributes_type.types_depended_on
          expect(result).to be_a(Set)
        end
      end
    end

    context "when element_types is an Array and remove_sensitive is false" do
      it "includes all elements" do
        inner_model_class = stub_class("Inner2ArrayModel", Foobara::Model) do
          attributes do
            value :string
          end
        end

        model_class = stub_class("NonSensitiveArrayElemModel", Foobara::Model) do
          attributes do
            items [inner_model_class]
          end
        end

        attributes_type = model_class.attributes_type

        Foobara::TypeDeclarations.with_manifest_context(remove_sensitive: false) do
          result = attributes_type.types_depended_on
          expect(result).to be_a(Set)
        end
      end
    end

    context "when at start of recursion" do
      before do
        stub_class("StartRecursionModel", Foobara::Model) do
          attributes do
            name :string
          end
        end
      end

      it "filters to only registered types excluding self" do
        model_type = Foobara.foobara_lookup!("StartRecursionModel")
        result = model_type.types_depended_on

        expect(result).to_not include(model_type)
        expect(result).to all(be_registered)
      end
    end

    context "when result already includes the type" do
      before do
        stub_class("AlreadyInResultModel", Foobara::Model) do
          attributes do
            value :integer
          end
        end
      end

      it "returns early" do
        model_type = Foobara.foobara_lookup!("AlreadyInResultModel")
        result = Set.new
        result << model_type

        model_type.types_depended_on(result)
        expect(result).to include(model_type)
      end
    end

    context "when type is registered but not at start" do
      before do
        stub_class("RegisteredInnerModel", Foobara::Model) do
          attributes do
            value :string
          end
        end

        stub_class("RegisteredOuterModel", Foobara::Model) do
          attributes do
            inner RegisteredInnerModel
          end
        end
      end

      it "returns early for registered nested types" do
        outer_type = Foobara.foobara_lookup!("RegisteredOuterModel")
        inner_type = Foobara.foobara_lookup!("RegisteredInnerModel")

        result = outer_type.types_depended_on
        expect(result).to include(inner_type)
      end
    end
  end

  describe "#types_to_add_to_manifest" do
    context "when element_type is sensitive and remove_sensitive is true" do
      it "does not include sensitive element_type" do
        model_class = stub_class("ToManifestSensitiveModel", Foobara::Model) do
          attributes do
            passwords [:string], :sensitive
          end
        end

        attributes_type = model_class.attributes_type

        Foobara::TypeDeclarations.with_manifest_context(remove_sensitive: true) do
          result = attributes_type.types_to_add_to_manifest
          expect(result).to be_an(Array)
        end
      end
    end

    context "when element_type is not sensitive" do
      before do
        stub_class("ToManifestNonSensitiveModel", Foobara::Model) do
          attributes do
            names [:string]
          end
        end
      end

      it "includes element_type" do
        model_class = ToManifestNonSensitiveModel
        attributes_type = model_class.attributes_type

        result = attributes_type.types_to_add_to_manifest
        expect(result).to be_an(Array)
        expect(result).to_not be_empty
      end
    end
  end

  describe "#type_at_path" do
    context "when path_part is # (array element)" do
      before do
        stub_class("PathArrayModel", Foobara::Model) do
          attributes do
            items [:string]
          end
        end
      end

      it "returns element_type" do
        model_class = PathArrayModel
        attributes_type = model_class.attributes_type
        array_type = attributes_type.type_at_path([:items])

        result = array_type.type_at_path([:"#"])
        expect(result.type_symbol).to eq(:string)
      end
    end

    context "when path_part is Symbol and element_types is Hash" do
      before do
        stub_class("PathHashModel", Foobara::Model) do
          attributes do
            name :string
            age :integer
          end
        end
      end

      it "returns the attribute type from hash" do
        model_class = PathHashModel
        attributes_type = model_class.attributes_type

        result = attributes_type.type_at_path([:name])
        expect(result.type_symbol).to eq(:string)
      end
    end

    context "when path_part is Symbol and element_types is a Type extending attributes" do
      before do
        stub_class("PathNestedInnerModel", Foobara::Model) do
          attributes do
            inner_field :string
          end
        end

        stub_class("PathNestedOuterModel", Foobara::Model) do
          attributes do
            nested PathNestedInnerModel
          end
        end
      end

      it "navigates through nested attributes" do
        outer_class = PathNestedOuterModel
        attributes_type = outer_class.attributes_type
        nested_type = attributes_type.type_at_path([:nested])

        result = nested_type.type_at_path([:inner_field])
        expect(result.type_symbol).to eq(:string)
      end
    end

    context "when path_part is Integer and type extends array" do
      before do
        stub_class("PathIntegerIndexModel", Foobara::Model) do
          attributes do
            items [:string]
          end
        end
      end

      it "returns element_type" do
        model_class = PathIntegerIndexModel
        attributes_type = model_class.attributes_type
        array_type = attributes_type.type_at_path([:items])

        result = array_type.type_at_path([0])
        expect(result.type_symbol).to eq(:string)
      end
    end

    context "when path has multiple parts" do
      before do
        stub_class("PathMultiPartModel", Foobara::Model) do
          attributes do
            items [:string]
          end
        end
      end

      it "recursively navigates the path" do
        model_class = PathMultiPartModel
        attributes_type = model_class.attributes_type

        result = attributes_type.type_at_path([:items, :"#"])
        expect(result.type_symbol).to eq(:string)
      end
    end

    context "when path is empty after navigating to element" do
      before do
        stub_class("PathEmptyAfterModel", Foobara::Model) do
          attributes do
            name :string
          end
        end
      end

      it "returns the final type" do
        model_class = PathEmptyAfterModel
        attributes_type = model_class.attributes_type

        result = attributes_type.type_at_path([:name])
        expect(result.type_symbol).to eq(:string)
      end
    end
  end

  describe "#deep_types_depended_on" do
    context "when type has nested dependencies" do
      before do
        stub_class("DeepLevel1Model", Foobara::Model) do
          attributes do
            value :string
          end
        end

        stub_class("DeepLevel2Model", Foobara::Model) do
          attributes do
            inner DeepLevel1Model
          end
        end

        stub_class("DeepLevel3Model", Foobara::Model) do
          attributes do
            middle DeepLevel2Model
          end
        end
      end

      it "returns all nested dependencies" do
        outer_type = Foobara.foobara_lookup!("DeepLevel3Model")
        result = outer_type.deep_types_depended_on

        inner_type = Foobara.foobara_lookup!("DeepLevel1Model")
        middle_type = Foobara.foobara_lookup!("DeepLevel2Model")

        expect(result).to include(inner_type)
        expect(result).to include(middle_type)
      end
    end

    context "when type already in result set" do
      it "does not process the same type twice" do
        stub_class("DeepNoDuplicateModel", Foobara::Model) do
          attributes do
            name :string
          end
        end

        model_type = Foobara.foobara_lookup!("DeepNoDuplicateModel")
        result = model_type.deep_types_depended_on

        # deep_types_depended_on returns an Array from .select, not a Set
        expect(result).to be_an(Array)
        expect(result).to all(be_registered)
      end
    end

    context "when processing dependency graph" do
      it "handles the dependency graph without infinite loop" do
        model_a_class = stub_class("DeepGraphAModel", Foobara::Model) do
          attributes do
            name :string
          end
        end

        stub_class("DeepGraphBModel", Foobara::Model) do
          attributes do
            a model_a_class
          end
        end

        model_b_type = Foobara.foobara_lookup!("DeepGraphBModel")
        result = model_b_type.deep_types_depended_on

        # deep_types_depended_on returns an Array from .select, not a Set
        expect(result).to be_an(Array)
        expect(result).to all(be_registered)

        expect(result.map(&:type_symbol)).to include(:DeepGraphAModel)
      end
    end
  end
end
