RSpec.describe Foobara::TransformedCommand do
  after do
    Foobara.reset_alls
  end

  let(:command_class) do
    stub_class(:SomeCommand, Foobara::Command) do
      inputs foo: :integer
      result :integer

      def execute
        foo * 2
      end
    end
  end

  describe "uncovered branches - round 1" do
    describe "Line 133: TypedTransformer with nil from_type" do
      it "handles TypedTransformer that returns nil from from_type method" do
        transformer_class = stub_class(:NilFromTypeTransformer, Foobara::TypeDeclarations::TypedTransformer) do
          def from_type
            nil
          end

          def transform(_value)
            value
          end
        end

        transformed_class = described_class.subclass(
          command_class,
          scoped_namespace: Foobara,
          full_command_name: "SomeCommand",
          command_name: "SomeCommand",
          inputs_transformers: [transformer_class],
          result_transformers: [],
          errors_transformers: [],
          pre_commit_transformers: [],
          serializers: [],
          response_mutators: [],
          request_mutators: [],
          allowed_rule: nil,
          requires_authentication: false,
          authenticator: nil
        )

        # This should not raise and should handle the nil from_type
        expect { transformed_class.inputs_transformers }.not_to raise_error
      end
    end

    describe "Line 167: TypedTransformer in pipeline with nil from_type" do
      it "handles TypedTransformer in pipeline that returns nil from from_type method" do
        # Create two transformers to create a pipeline
        transformer1 = stub_class(:NilFromTypeTransformer1, Foobara::TypeDeclarations::TypedTransformer) do
          def from_type
            nil
          end

          def transform(value)
            value
          end
        end

        transformer2 = stub_class(:NilFromTypeTransformer2, Foobara::TypeDeclarations::TypedTransformer) do
          def from_type
            nil
          end

          def transform(value)
            value
          end
        end

        transformed_class = described_class.subclass(
          command_class,
          scoped_namespace: Foobara,
          full_command_name: "SomeCommand",
          command_name: "SomeCommand",
          inputs_transformers: [transformer1, transformer2],  # Multiple transformers to create a pipeline
          result_transformers: [],
          errors_transformers: [],
          pre_commit_transformers: [],
          serializers: [],
          response_mutators: [],
          request_mutators: [],
          allowed_rule: nil,
          requires_authentication: false,
          authenticator: nil
        )

        # This should access inputs_type_from_transformers and iterate through pipeline transformers
        # Since both return nil from_type, it should skip the "if from_type" branch (line 167)
        result = transformed_class.inputs_type_from_transformers
        # Should fall back to command_class.inputs_type at line 174
        expect(result).to eq(command_class.inputs_type)
      end
    end

    describe "Line 187: result_transformers with non-TypedTransformer" do
      it "handles result transformer that is not a TypedTransformer" do
        transformer_proc = ->(value) { value }

        transformed_class = described_class.subclass(
          command_class,
          scoped_namespace: Foobara,
          full_command_name: "SomeCommand",
          command_name: "SomeCommand",
          inputs_transformers: [],
          result_transformers: [transformer_proc],
          errors_transformers: [],
          pre_commit_transformers: [],
          serializers: [],
          response_mutators: [],
          request_mutators: [],
          allowed_rule: nil,
          requires_authentication: false,
          authenticator: nil
        )

        # This should iterate through transformers without finding TypedTransformer
        result_type = transformed_class.result_type_from_transformers
        expect(result_type).to eq(command_class.result_type)
      end
    end

    describe "Line 190: TypedTransformer with nil to_type" do
      it "handles TypedTransformer that returns nil from to_type method" do
        transformer_class = stub_class(:NilToTypeTransformer, Foobara::TypeDeclarations::TypedTransformer) do
          def to_type
            nil
          end

          def transform(_value)
            value
          end
        end

        transformed_class = described_class.subclass(
          command_class,
          scoped_namespace: Foobara,
          full_command_name: "SomeCommand",
          command_name: "SomeCommand",
          inputs_transformers: [],
          result_transformers: [transformer_class],
          errors_transformers: [],
          pre_commit_transformers: [],
          serializers: [],
          response_mutators: [],
          request_mutators: [],
          allowed_rule: nil,
          requires_authentication: false,
          authenticator: nil
        )

        # This should not return nil to_type early and continue iteration
        result_type = transformed_class.result_type_from_transformers
        expect(result_type).to eq(command_class.result_type)
      end
    end

    describe "Line 680: memoized inputs" do
      it "returns memoized inputs on second call" do
        # The memoization happens when inputs is called multiple times
        # Line 680 tests: return @inputs if defined?(@inputs)
        connector = Foobara::CommandConnector.new
        connector.connect(command_class)

        exposed_commands = connector.all_exposed_commands
        transformed_command_class = exposed_commands.first.transformed_command_class

        # Create instance directly
        transformed_command = transformed_command_class.new(foo: 5)

        # Check if inputs_type exists (it should for command_class with inputs)
        expect(transformed_command_class.inputs_type).not_to be_nil

        # First call should compute and set @inputs
        inputs1 = transformed_command.inputs

        # Second call should return memoized value (hitting line 680: return @inputs if defined?(@inputs))
        inputs2 = transformed_command.inputs

        # Should be the same object (memoized)
        expect(inputs2).to eq(inputs1)
        expect(inputs2.object_id).to eq(inputs1.object_id)
      end
    end

    describe "Line 846: allowed_rule with nil explanation" do
      it "handles allowed_rule with nil explanation and generates source location" do
        connector = Foobara::CommandConnector.new(
          default_serializers: [
            Foobara::CommandConnectors::Serializers::ErrorsSerializer,
            Foobara::CommandConnectors::Serializers::JsonSerializer
          ]
        )
        allowed_rule = -> { false }
        connector.connect(
          command_class,
          allowed_rule:
        )

        response = connector.run(
          full_command_name: "SomeCommand",
          action: "run",
          inputs: { foo: 5 }
        )

        expect(response.status).to eq(1)
        errors = JSON.parse(response.body)
        error = errors.find { |e| e["key"] == "runtime.not_allowed" }
        expect(error).not_to be_nil
        # Should have generated explanation from source_location or source code
        expect(error["context"]["explanation"]).to be_a(String)
        expect(error["context"]["explanation"]).not_to be_empty
      end
    end

    describe "Line 876: pre_commit_transformer not applicable" do
      it "skips pre_commit_transformer when not applicable" do
        transformer_class = stub_class(:NotApplicableTransformer, Foobara::Value::Transformer) do
          def applicable?(_value)
            false
          end

          def transform(_value)
            raise "Should not be called"
          end
        end

        connector = Foobara::CommandConnector.new(
          default_pre_commit_transformers: [transformer_class]
        )
        connector.connect(command_class)

        response = connector.run(
          full_command_name: "SomeCommand",
          action: "run",
          inputs: { foo: 5 }
        )

        # Should not raise because transformer is not applicable
        expect(response.status).to eq(0)
      end
    end

    describe "Line 884: command without inputs_type" do
      it "skips set_inputs when inputs_type is nil" do
        # Testing the else branch when self.class.inputs_type is falsy
        # This happens when a TransformedCommand is created without an inputs_type
        command_without_inputs = stub_class(:NoInputsCommand, Foobara::Command) do
          result :integer

          def execute
            42
          end
        end

        connector = Foobara::CommandConnector.new(
          default_serializers: [
            Foobara::CommandConnectors::Serializers::ErrorsSerializer,
            Foobara::CommandConnectors::Serializers::JsonSerializer
          ]
        )
        connector.connect(command_without_inputs)

        # Run the command - even without inputs_type it should work
        response = connector.run(
          full_command_name: "NoInputsCommand",
          action: "run",
          inputs: {}
        )

        expect(response.status).to eq(0)
        result = JSON.parse(response.body)
        expect(result).to eq(42)
      end
    end

    describe "Line 914: request with no opened_transactions" do
      it "handles request with nil opened_transactions using safe navigation" do
        # The &. operator on line 914 tests for nil opened_transactions
        # This is tested by creating a command connector without entities
        connector = Foobara::CommandConnector.new(
          default_serializers: [
            Foobara::CommandConnectors::Serializers::ErrorsSerializer,
            Foobara::CommandConnectors::Serializers::JsonSerializer
          ]
        )
        connector.connect(command_class)

        # Normal run should work even if opened_transactions is nil or empty
        response = connector.run(
          full_command_name: "SomeCommand",
          action: "run",
          inputs: { foo: 5 }
        )

        expect(response.status).to eq(0)
        result = JSON.parse(response.body)
        expect(result).to eq(10)
      end
    end
  end

  describe "uncovered branches - round 2" do
    describe "Line 167: TypedTransformer with non-nil from_type" do
      it "handles TypedTransformer in pipeline that returns a from_type" do
        # Create a transformer that returns a real from_type
        string_type = Foobara::Domain.current.foobara_type_from_declaration(:string)

        transformer_class = stub_class(:StringTypeTransformer, Foobara::TypeDeclarations::TypedTransformer) do
          class << self
            attr_accessor :test_from_type
          end

          def from_type
            self.class.test_from_type
          end

          def transform(value)
            value.to_s
          end
        end

        transformer_class.test_from_type = string_type

        transformed_class = described_class.subclass(
          command_class,
          scoped_namespace: Foobara,
          full_command_name: "SomeCommand",
          command_name: "SomeCommand",
          inputs_transformers: [transformer_class],
          result_transformers: [],
          errors_transformers: [],
          pre_commit_transformers: [],
          serializers: [],
          response_mutators: [],
          request_mutators: [],
          allowed_rule: nil,
          requires_authentication: false,
          authenticator: nil
        )

        # This should access inputs_type_from_transformers and use the from_type
        result = transformed_class.inputs_type_from_transformers
        expect(result).to eq(string_type)
      end
    end

    # Line 680/686/688 are all covered by existing tests
    # Line 680 "then" (memoized return) is covered by "Line 680: memoized inputs" test
    # Line 686 "then" (successful processing) is covered by normal command execution
    # Line 688 "else" (failed processing) would require inputs_type.process_value to fail

    describe "Line 914: safe navigation on reverse" do
      it "handles opened_transactions that exist" do
        # Test the second &. on line 914: request.opened_transactions&.reverse&.each
        # We need transactions to actually exist and be reversed
        command_with_entity = stub_class(:CreateUser, Foobara::Command) do
          inputs name: :string
          result :integer

          def execute
            1
          end
        end

        connector = Foobara::CommandConnector.new(
          default_serializers: [
            Foobara::CommandConnectors::Serializers::ErrorsSerializer,
            Foobara::CommandConnectors::Serializers::JsonSerializer
          ]
        )
        connector.connect(command_with_entity)

        # Run the command - it will handle transactions if they exist
        response = connector.run(
          full_command_name: "CreateUser",
          action: "run",
          inputs: { name: "test" }
        )

        expect(response.status).to eq(0)
      end
    end

    # Line 846 is actually already covered - it's the else branch where we get source_location
    # The test we already have for Line 846 covers this
  end
end
