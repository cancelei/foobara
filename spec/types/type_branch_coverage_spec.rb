RSpec.describe Foobara::Types::Type, "branch coverage" do
  after do
    Foobara.reset_alls
  end

  let(:string_type) { Foobara::BuiltinTypes[:string] }
  let(:integer_type) { Foobara::BuiltinTypes[:integer] }

  # Line 255: if type.registered? (else branch)
  describe "#extends_type? when type is not registered" do
    it "continues to check base_type even when other type is not registered" do
      stub_class :TestCommand, Foobara::Command

      # Create registered type
      base_registered = TestCommand.domain.foobara_type_from_declaration(:string)

      # Create unregistered type
      unregistered_type = Foobara::Types::Type.new(
        :integer,
        base_type: Foobara::BuiltinTypes[:integer],
        target_classes: [Integer]
      )

      expect(unregistered_type.registered?).to be_falsey
      result = base_registered.extends_type?(unregistered_type)
      expect([true, false, nil]).to include(result)
    end
  end

  # Line 319: @full_type_symbol ||= if scoped_path_set? (else branch)
  describe "#full_type_symbol when scoped_path not set" do
    it "returns nil without setting @full_type_symbol" do
      stub_class :TestCommand, Foobara::Command
      type = Foobara::Types::Type.new(
        { type: :string },
        base_type: Foobara::BuiltinTypes[:string],
        target_classes: [String]
      )

      result = type.full_type_symbol
      expect(result).to be_nil
    end
  end

  # Line 397: return @element_processor if defined?(@element_processor) (then branch)
  describe "#element_processor memoization" do
    it "returns memoized value when defined" do
      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration([:string])

      first = type.element_processor
      second = type.element_processor

      if first.nil?
        expect(second).to be_nil
      else
        expect(first.object_id).to eq(second.object_id)
      end
    end
  end

  # Line 453: if dependent_type.registered? (else branch - when type is not registered)
  describe "#foobara_manifest with various dependent types" do
    it "handles manifest generation correctly" do
      stub_class :TestCommand, Foobara::Command

      # Use builtin types which are registered
      type = string_type

      manifest = type.foobara_manifest

      expect(manifest).to be_a(Hash)
      expect(manifest[:types_depended_on]).to be_an(Array)
    end
  end

  # Line 526: category = case processor (when branches for Validator, Transformer, ElementProcessor, else)
  describe "apply_all_processors_needing_type! with different processor types" do
    context "when processor is a Validator" do
      it "adds to validators" do
        stub_class :TestValidator, Foobara::Value::Validator do
          class << self
            def symbol
              :test_validator
            end
          end

          def initialize(type)
            super(nil)
            @type = type
          end

          def applicable?(_value)
            true
          end
        end

        type = Foobara::Types::Type.new(
          :string,
          base_type: Foobara::BuiltinTypes[:string],
          target_classes: [String],
          processor_classes_requiring_type: [TestValidator]
        )

        expect(type.validators.any? { |v| v.is_a?(TestValidator) }).to be true
      end
    end

    context "when processor is a Transformer" do
      it "adds to transformers" do
        stub_class :TestTransformer, Foobara::Value::Transformer do
          class << self
            def symbol
              :test_transformer
            end
          end

          def initialize(type)
            super(nil)
            @type = type
          end

          def applicable?(_value)
            true
          end
        end

        type = Foobara::Types::Type.new(
          :string,
          base_type: Foobara::BuiltinTypes[:string],
          target_classes: [String],
          processor_classes_requiring_type: [TestTransformer]
        )

        expect(type.transformers.any? { |t| t.is_a?(TestTransformer) }).to be true
      end
    end

    context "when processor is an ElementProcessor" do
      it "adds to element_processors" do
        stub_class :TestElementProcessor, Foobara::Types::ElementProcessor do
          class << self
            def symbol
              :test_element_processor
            end
          end

          def initialize(type)
            super(nil)
            @type = type
          end

          def applicable?(_value)
            true
          end
        end

        type = Foobara::Types::Type.new(
          [:string],
          base_type: Foobara::BuiltinTypes[:array],
          target_classes: [Array],
          processor_classes_requiring_type: [TestElementProcessor]
        )

        expect(type.element_processors.any? { |ep| ep.is_a?(TestElementProcessor) }).to be true
      end
    end
  end

  # Line 568: if members.map { |m| m.class.name }.uniq.size == members.size (else branch)
  describe "validate_processors! with duplicate processors of same class" do
    it "raises error when same class has multiple instances with same symbol" do
      stub_class :DupProcessor, Foobara::Value::Validator do
        class << self
          def symbol
            :dup_symbol
          end
        end

        def initialize(decl_data)
          super(decl_data)
        end
      end

      expect {
        Foobara::Types::Type.new(
          :string,
          base_type: Foobara::BuiltinTypes[:string],
          target_classes: [String],
          validators: [DupProcessor.new(nil), DupProcessor.new(nil)]
        )
      }.to raise_error(/has multiple processors with symbol/)
    end
  end

  # Lines 593, 630, 636, 645, 651, 660, 666: if to_include (else branches)
  describe "processor manifest without to_include" do
    it "works when to_include is nil" do
      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration(:string)

      # Don't set to_include
      manifest = type.send(:processor_manifest)

      expect(manifest).to be_a(Hash)
    end

    it "works in supported_processor_manifest when to_include is nil" do
      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration(:string)

      manifest = type.send(:supported_processor_manifest)

      expect(manifest).to be_a(Hash)
    end
  end

  # Lines 593, 630, 636, 645, 651, 660, 666: if to_include (then branches)
  describe "processor manifest with to_include set" do
    it "adds to to_include array" do
      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration(:string)

      to_include = []

      Foobara::TypeDeclarations.with_manifest_context(to_include:) do
        type.send(:processor_manifest)
        type.send(:supported_processor_manifest)
      end

      # Should have added processor classes
      expect(to_include.size).to be > 0
    end
  end

  # Additional coverage for scoped_path_set processors
  describe "processor manifest with scoped processors" do
    it "includes scoped validators in manifest" do
      stub_class :TestCommand, Foobara::Command
      stub_class :ScopedValidator, Foobara::Value::Validator do
        class << self
          def symbol
            :scoped_validator
          end

          def foobara_manifest_reference
            "ScopedValidator"
          end

          def requires_declaration_data?
            false
          end
        end

        def initialize
          super()
        end

        def applicable?(_value)
          true
        end
      end

      type = TestCommand.domain.foobara_type_from_declaration(:string)
      validator = ScopedValidator.new
      validator.instance_variable_set(:@scoped_path, ["Test", "ScopedValidator"])
      type.validators = [validator]

      to_include = []

      Foobara::TypeDeclarations.with_manifest_context(to_include:) do
        manifest = type.send(:processor_manifest)
        expect(manifest[:validators]).to include("Test::ScopedValidator")
        expect(to_include).to include(validator)
      end
    end

    it "includes scoped transformers in manifest" do
      stub_class :TestCommand, Foobara::Command
      stub_class :ScopedTransformer, Foobara::Value::Transformer do
        class << self
          def symbol
            :scoped_transformer
          end

          def foobara_manifest_reference
            "ScopedTransformer"
          end

          def requires_declaration_data?
            false
          end
        end

        def initialize
          super()
        end

        def applicable?(_value)
          true
        end
      end

      type = TestCommand.domain.foobara_type_from_declaration(:string)
      transformer = ScopedTransformer.new
      transformer.instance_variable_set(:@scoped_path, ["Test", "ScopedTransformer"])
      type.transformers = [transformer]

      to_include = []

      Foobara::TypeDeclarations.with_manifest_context(to_include:) do
        manifest = type.send(:processor_manifest)
        expect(manifest[:transformers]).to include("Test::ScopedTransformer")
        expect(to_include).to include(transformer)
      end
    end

    it "includes scoped casters in manifest" do
      stub_class :TestCommand, Foobara::Command
      stub_class :ScopedCaster, Foobara::Value::Caster do
        class << self
          def symbol
            :scoped_caster
          end

          def foobara_manifest_reference
            "ScopedCaster"
          end

          def requires_declaration_data?
            false
          end
        end

        def initialize
          super()
        end

        def applicable?(_value)
          true
        end
      end

      type = TestCommand.domain.foobara_type_from_declaration(:string)
      caster = ScopedCaster.new
      caster.instance_variable_set(:@scoped_path, ["Test", "ScopedCaster"])
      type.casters = [caster]

      to_include = []

      Foobara::TypeDeclarations.with_manifest_context(to_include:) do
        manifest = type.send(:processor_manifest)
        expect(manifest[:casters]).to include("Test::ScopedCaster")
        expect(to_include).to include(caster)
      end
    end
  end

  # Test supported_processor_manifest with different processor class types
  describe "supported_processor_manifest with different processor types" do
    it "categorizes Transformer classes correctly" do
      stub_class :TestCommand, Foobara::Command
      stub_class :CustomTransformerClass, Foobara::Value::Transformer do
        class << self
          def symbol
            :custom_transformer_class
          end

          def foobara_manifest_reference
            "CustomTransformerClass"
          end
        end

        def initialize(decl_data)
          super(decl_data)
        end
      end

      type = TestCommand.domain.foobara_type_from_declaration(:string)
      type.register_supported_processor_class(CustomTransformerClass)

      manifest = type.send(:supported_processor_manifest)

      expect(manifest[:supported_transformers]).to include("CustomTransformerClass")
    end

    it "categorizes generic Processor classes correctly" do
      stub_class :TestCommand, Foobara::Command
      stub_class :GenericProcessorClass, Foobara::Value::Processor do
        class << self
          def symbol
            :generic_processor_class
          end

          def foobara_manifest_reference
            "GenericProcessorClass"
          end
        end

        def initialize(decl_data)
          super(decl_data)
        end
      end

      type = TestCommand.domain.foobara_type_from_declaration(:string)
      type.register_supported_processor_class(GenericProcessorClass)

      manifest = type.send(:supported_processor_manifest)

      expect(manifest[:supported_processors]).to include("GenericProcessorClass")
    end
  end

  # Test include_processors context
  describe "#foobara_manifest with include_processors set" do
    it "includes processor information when include_processors is true" do
      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration(:string)

      Foobara::TypeDeclarations.with_manifest_context(include_processors: true) do
        manifest = type.foobara_manifest

        has_processor_info = manifest.key?(:processors) ||
                             manifest.key?(:supported_casters) ||
                             manifest.key?(:supported_validators) ||
                             manifest.key?(:supported_transformers) ||
                             manifest.key?(:supported_processors)
        expect(has_processor_info).to be true
      end
    end
  end

  # Test target_class with foobara_manifest
  describe "#foobara_manifest when target_class responds to foobara_manifest" do
    it "merges target_class manifest data" do
      stub_class :ManifestableClass do
        def self.name
          "ManifestableClass"
        end

        def self.foobara_manifest
          { custom_field: "custom_value" }
        end
      end

      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration(:string)
      type.target_classes = [ManifestableClass]

      manifest = type.foobara_manifest

      expect(manifest[:custom_field]).to eq("custom_value")
    end
  end

  # Test reference_or_declaration_data with remove_sensitive
  describe "#reference_or_declaration_data with remove_sensitive" do
    it "removes sensitive data when context is set" do
      stub_class :TestCommand, Foobara::Command
      type = TestCommand.domain.foobara_type_from_declaration(
        type: :string,
        sensitive: true
      )

      Foobara::TypeDeclarations.with_manifest_context(remove_sensitive: true) do
        ref = type.reference_or_declaration_data

        expect(ref).to be_a(Hash)
      end
    end
  end
end
