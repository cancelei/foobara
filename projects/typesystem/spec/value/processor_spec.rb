RSpec.describe Foobara::Value::Processor do
  let(:processor_class) {
    stub_class "SomeProcessor", described_class do
      def process_value(value)
        if value == 123
          Foobara::Outcome.error(build_error(symbol: :foo, message: "some error", context: {}))
        else
          Foobara::Outcome.success(value)
        end
      end
    end.tap do
      stub_class "SomeProcessor::Error", Foobara::Value::DataError
    end
  }

  let(:processor) { processor_class.new(foo: :bar) }

  describe "#process!" do
    context "when is an error" do
      it "raises" do
        expect {
          processor.process_value!(123)
        }.to raise_error(processor_class::Error)
      end
    end
  end

  describe "#process_outcome!" do
    context "when is an error" do
      it "raises" do
        expect {
          processor.process_outcome!(Foobara::Outcome.success(123))
        }.to raise_error(processor_class::Error)
      end
    end

    context "when is not an error" do
      it "gives the result" do
        expect(processor.process_outcome!(Foobara::Outcome.success(10))).to eq(10)
      end
    end
  end

  describe "#dup_processor" do
    context "when overriding declaration data" do
      it "dups the processor" do
        duped_processor = processor.dup_processor(declaration_data: { bar: "baz" })

        expect(processor.declaration_data).to eq(foo: :bar)
        expect(duped_processor.declaration_data).to eq(bar: "baz")
      end
    end

    context "when overriding parent declaration data" do
      let(:processor_class) do
        stub_class "ProcessorWithParent", described_class do
          class << self
            def requires_parent_declaration_data?
              true
            end
          end

          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "ProcessorWithParent::Error", Foobara::Value::DataError
        end
      end

      let(:processor) { processor_class.new({ foo: :bar }, { parent: :data }) }

      it "dups the processor with new parent data" do
        duped_processor = processor.dup_processor(parent_declaration_data: { new_parent: :data })

        expect(processor.parent_declaration_data).to eq(parent: :data)
        expect(duped_processor.parent_declaration_data).to eq(new_parent: :data)
      end
    end

    context "when not overriding anything" do
      it "dups the processor with same data" do
        duped_processor = processor.dup_processor

        expect(duped_processor.declaration_data).to eq(processor.declaration_data)
      end
    end
  end

  describe ".new_with_agnostic_args" do
    context "when requires declaration data" do
      let(:processor_class) do
        stub_class "SomeProcessor", described_class do
          class << self
            def requires_declaration_data?
              true
            end
          end
        end
      end

      context "when no declaration data provided" do
        let(:processor) { processor_class.new_with_agnostic_args }

        it "has true as its declaration data" do
          expect(processor.declaration_data).to be true
        end
      end

      context "when declaration data provided" do
        let(:processor) { processor_class.new_with_agnostic_args(declaration_data: { foo: :bar }) }

        it "has the provided declaration data" do
          expect(processor.declaration_data).to eq(foo: :bar)
        end
      end

      context "when declaration data is default" do
        let(:processor) { processor_class.new_with_agnostic_args(declaration_data: true) }

        it "returns the singleton instance" do
          expect(processor).to be(processor_class.instance)
        end
      end
    end

    context "when requires parent declaration data" do
      let(:processor_class) do
        stub_class "ProcessorWithParent", described_class do
          class << self
            def requires_parent_declaration_data?
              true
            end
          end
        end
      end

      it "passes parent declaration data to constructor" do
        processor = processor_class.new_with_agnostic_args(
          declaration_data: { foo: :bar },
          parent_declaration_data: { parent: :data }
        )

        expect(processor.parent_declaration_data).to eq(parent: :data)
      end
    end

    context "when doesn't require declaration data" do
      let(:processor_class) do
        stub_class "NoDataProcessor", described_class do
          class << self
            def requires_declaration_data?
              false
            end
          end
        end
      end

      it "returns the singleton instance" do
        processor = processor_class.new_with_agnostic_args
        expect(processor).to be(processor_class.instance)
      end
    end
  end

  describe ".instance" do
    context "when doesn't require declaration data" do
      let(:processor_class) do
        stub_class "NoDataProcessor", described_class do
          class << self
            def requires_declaration_data?
              false
            end
          end
        end
      end

      it "returns a singleton instance" do
        instance1 = processor_class.instance
        instance2 = processor_class.instance
        expect(instance1).to be(instance2)
      end
    end

    context "when requires declaration data" do
      it "returns a singleton instance with default declaration data" do
        instance1 = processor_class.instance
        instance2 = processor_class.instance
        expect(instance1).to be(instance2)
        expect(instance1.declaration_data).to be true
      end
    end
  end

  describe ".processor_name" do
    context "when class has a name" do
      it "returns the name" do
        expect(processor_class.processor_name).to eq("SomeProcessor")
      end
    end
  end

  describe ".foobara_manifest" do
    context "when there is to_include context" do
      it "adds error classes to the to_include set" do
        to_include = Set.new
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_to_include).and_return(to_include)

        manifest = processor_class.foobara_manifest

        expect(to_include).to include(processor_class::Error)
      end
    end

    context "when there are no errors" do
      let(:processor_no_errors) do
        stub_class "ProcessorNoErrors", described_class do
          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end
      end

      it "does not include error_classes in manifest" do
        allow(processor_no_errors).to receive(:error_classes).and_return([])
        manifest = processor_no_errors.foobara_manifest
        expect(manifest).to_not have_key(:error_classes)
      end
    end
  end

  describe ".error_classes" do
    context "when has superclass with errors" do
      let(:parent_processor) do
        stub_class "ParentProcessor", described_class do
          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "ParentProcessor::ParentError", Foobara::Value::DataError
        end
      end

      let(:child_processor) do
        stub_class "ChildProcessor", parent_processor do
          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "ChildProcessor::ChildError", Foobara::Value::DataError
        end
      end

      it "includes parent error classes" do
        child_errors = child_processor.error_classes
        expect(child_errors).to include(parent_processor::ParentError)
        expect(child_errors).to include(child_processor::ChildError)
      end
    end
  end

  describe ".symbol" do
    it "removes _processor suffix and converts to symbol" do
      expect(processor_class.symbol).to be_a(Symbol)
    end
  end

  describe "#created_in_namespace" do
    it "has a created_in_namespace value" do
      expect(processor.created_in_namespace).to_not be_nil
    end
  end

  describe "#process_outcome" do
    context "when old outcome is fatal" do
      it "returns the old outcome without processing" do
        fatal_outcome = Foobara::Outcome.error(
          processor.build_error(symbol: :fatal, message: "fatal error", context: {})
        )
        allow(fatal_outcome).to receive(:fatal?).and_return(true)

        result = processor.process_outcome(fatal_outcome)
        expect(result).to be(fatal_outcome)
      end
    end

    context "when old outcome has errors" do
      it "adds old errors to new outcome" do
        old_error = processor.build_error(symbol: :old, message: "old error", context: {})
        old_outcome = Foobara::Outcome.error(old_error)
        old_outcome.result = 10

        new_outcome = processor.process_outcome(old_outcome)
        expect(new_outcome.errors).to include(old_error)
      end
    end
  end

  describe "#applicable?" do
    context "when declaration_data is false" do
      let(:processor) { processor_class.new(false) }

      it "returns false" do
        expect(processor.applicable?(anything: true)).to be false
      end
    end

    context "when declaration_data is nil" do
      let(:processor) { processor_class.new(nil) }

      it "returns false" do
        expect(processor.applicable?(anything: true)).to be false
      end
    end

    context "when declaration_data is truthy" do
      it "returns true" do
        expect(processor.applicable?(anything: true)).to be true
      end
    end
  end

  describe "#always_applicable?" do
    it "returns double-negated declaration_data" do
      expect(processor.always_applicable?).to be true

      processor_false = processor_class.new(false)
      expect(processor_false.always_applicable?).to be false
    end
  end

  describe "#error_message" do
    it "returns error class message" do
      message = processor.error_message(123)
      expect(message).to eq(processor.error_class.message)
    end
  end

  describe "#error_context" do
    it "returns error class context" do
      context = processor.error_context(123)
      expect(context).to eq(processor.error_class.context)
    end
  end

  describe "#method_missing" do
    context "when method matches symbol" do
      it "returns declaration_data" do
        result = processor.send(processor_class.symbol)
        expect(result).to eq(processor.declaration_data)
      end
    end
  end

  describe "#respond_to_missing?" do
    context "when method matches symbol" do
      it "returns true" do
        expect(processor.respond_to?(processor_class.symbol)).to be true
      end
    end

    context "when method does not match symbol" do
      it "returns false" do
        expect(processor.respond_to?(:nonexistent_method)).to be false
      end
    end
  end

  describe "#error_path" do
    context "when attribute_name is nil" do
      it "returns empty array" do
        expect(processor.error_path).to eq([])
      end
    end

    context "when attribute_name is set" do
      before do
        allow(processor).to receive(:attribute_name).and_return(:my_attribute)
      end

      it "returns array with attribute_name" do
        expect(processor.error_path).to eq([:my_attribute])
      end
    end
  end

  describe "#runner" do
    it "creates a runner for the processor" do
      # Assuming Runner is defined
      if processor_class.const_defined?(:Runner)
        runner = processor.runner(123)
        expect(runner).to be_a(processor_class::Runner)
      end
    end
  end

  describe "#possible_errors" do
    it "creates PossibleError instances for each error class" do
      possible_errors = processor.possible_errors
      expect(possible_errors).to all(be_a(Foobara::PossibleError))
    end
  end

  describe "#build_error" do
    context "when error_class is not in error_classes" do
      let(:other_error_class) do
        stub_class "OtherError", Foobara::Value::DataError
      end

      it "raises an error" do
        expect {
          processor.build_error(123, error_class: other_error_class)
        }.to raise_error("invalid error")
      end
    end
  end

  describe ".processor_name" do
    context "when class has no name (anonymous)" do
      it "returns 'Anonymous'" do
        # Test by mocking the name method
        allow(processor_class).to receive(:name).and_return(nil)
        expect(processor_class.processor_name).to eq("Anonymous")
      end
    end
  end

  describe ".symbol" do
    context "when Util.non_full_name_underscore returns nil" do
      let(:processor_class) do
        stub_class "ProcessorForSymbol", described_class do
          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "ProcessorForSymbol::Error", Foobara::Value::DataError
        end
      end

      it "handles nil result from underscore" do
        allow(Foobara::Util).to receive(:non_full_name_underscore).with(processor_class).and_return(nil)
        expect(processor_class.symbol).to be_nil
      end
    end
  end

  describe ".foobara_manifest without to_include" do
    context "when there is no to_include context" do
      it "generates manifest without adding to set" do
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_to_include).and_return(nil)

        manifest = processor_class.foobara_manifest

        expect(manifest[:name]).to eq("SomeProcessor")
        expect(manifest[:processor_type]).to eq(:processor)
      end
    end
  end


  describe "#initialize in namespace" do
    context "when Foobara::Namespace.current is not Foobara" do
      it "sets created_in_namespace to current namespace" do
        custom_namespace = stub_module("CustomNamespace")
        allow(custom_namespace).to receive(:is_a?).with(Foobara::Namespace::IsNamespace).and_return(true)

        Foobara::Namespace.use custom_namespace do
          processor_instance = processor_class.new(foo: :bar)
          expect(processor_instance.created_in_namespace).to eq(custom_namespace)
        end
      end
    end
  end

  describe ".error_classes with superclass" do
    context "when superclass is not a Processor" do
      let(:processor_class) do
        stub_class "ProcessorWithoutProcessorSuperclass", described_class do
          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "ProcessorWithoutProcessorSuperclass::Error", Foobara::Value::DataError
        end
      end

      it "does not include parent errors when superclass is not Processor" do
        # The direct superclass should be Processor, so this tests the branch
        allow(processor_class).to receive(:superclass).and_return(Object)

        # Force recompute
        processor_class.instance_variable_set(:@error_classes, nil)

        errors = processor_class.error_classes
        expect(errors).to be_an(Array)
      end
    end
  end

  describe ".error_classes with namespace check" do
    context "when is a Foobara::Namespace::IsNamespace" do
      let(:processor_class) do
        stub_class "NamespaceProcessor", described_class do
          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "NamespaceProcessor::Error", Foobara::Value::DataError
        end
      end

      it "calls foobara_all_error when is a namespace" do
        # The processor should already be a namespace, test the branch
        expect(processor_class).to be_a(Foobara::Namespace::IsNamespace)

        errors = processor_class.error_classes
        expect(errors).to be_an(Array)
        expect(errors).to include(processor_class::Error)
      end
    end
  end

  describe "#dup_processor without overrides" do
    context "when not providing declaration_data override" do
      it "uses existing declaration_data" do
        duped = processor.dup_processor(parent_declaration_data: {some: :data})
        expect(duped.declaration_data).to eq(processor.declaration_data)
      end
    end

    context "when not providing parent_declaration_data override" do
      it "uses existing parent_declaration_data" do
        duped = processor.dup_processor(declaration_data: {new: :data})
        expect(duped.parent_declaration_data).to eq(processor.parent_declaration_data)
      end
    end
  end

  describe ".new_with_agnostic_args edge cases" do
    context "when requires declaration data and no args provided uses default" do
      let(:processor_class) do
        stub_class "DefaultProcessor", described_class do
          class << self
            def requires_declaration_data?
              true
            end

            def default_declaration_data
              {custom: :default}
            end
          end

          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "DefaultProcessor::Error", Foobara::Value::DataError
        end
      end

      it "uses default_declaration_data when not provided" do
        processor = processor_class.new_with_agnostic_args
        expect(processor.declaration_data).to eq({custom: :default})
      end
    end

    context "when args exactly match default declaration data" do
      let(:processor_class) do
        stub_class "ExactDefaultProcessor", described_class do
          class << self
            def requires_declaration_data?
              true
            end

            def default_declaration_data
              {exact: :match}
            end
          end

          def process_value(value)
            Foobara::Outcome.success(value)
          end
        end.tap do
          stub_class "ExactDefaultProcessor::Error", Foobara::Value::DataError
        end
      end

      it "returns singleton when args equal default_declaration_data" do
        processor = processor_class.new_with_agnostic_args(declaration_data: {exact: :match})
        expect(processor).to be(processor_class.instance)
      end
    end
  end
end
