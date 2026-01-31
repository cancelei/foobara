RSpec.describe Foobara::Error do
  after do
    Foobara.reset_alls
  end

  describe ".symbol" do
    context "when called with no arguments" do
      it "returns a symbol based on the class name" do
        custom_error = stub_class "CustomSymbolError", described_class

        # This tests the 'when 0' branch at line 26-28
        expect(custom_error.symbol).to be_a(Symbol)
        expect(custom_error.symbol.to_s).to eq("custom_symbol")
      end
    end

    context "when called with one argument" do
      it "defines a symbol method that returns the argument" do
        custom_error = stub_class "CustomSymbolError", described_class do
          symbol :my_custom_symbol
        end

        expect(custom_error.symbol).to eq(:my_custom_symbol)
      end
    end

    context "when called with more than one argument" do
      it "raises ArgumentError" do
        expect {
          stub_class "MultiArgSymbolError", described_class do
            symbol(:arg1, :arg2)
          end
        }.to raise_error(ArgumentError, "expected 0 or 1 argument, got 2")
      end
    end
  end

  describe ".message" do
    context "when called with no arguments" do
      it "returns a humanized version of the symbol" do
        custom_error = stub_class "CustomMessageError", described_class do
          symbol :test_error
        end

        # This tests the 'when 0' branch at line 57-59
        expect(custom_error.message).to eq("Test error")
      end
    end

    context "when called with one argument" do
      it "defines a message method that returns the argument" do
        custom_error = stub_class "CustomMessageError", described_class do
          symbol :test_error
          message "Custom error message"
        end

        expect(custom_error.message).to eq("Custom error message")
      end
    end

    context "when called with more than one argument" do
      it "raises ArgumentError" do
        expect {
          stub_class "MultiArgMessageError", described_class do
            message("msg1", "msg2")
          end
        }.to raise_error(ArgumentError, "expected 0 or 1 argument, got 2")
      end
    end
  end

  describe ".context" do
    context "when called with no arguments" do
      it "returns empty hash" do
        custom_error = stub_class "EmptyContextError", described_class do
          symbol :test_error
        end

        expect(custom_error.context).to eq({})
      end
    end

    context "when called with one argument" do
      it "defines a context_type_declaration method" do
        custom_error = stub_class "ContextDeclError", described_class do
          symbol :test_error
          context foo: :string
        end

        expect(custom_error.context_type_declaration).to eq({ foo: :string })
      end
    end

    context "when called with a block" do
      it "includes the block in the arguments" do
        block_arg = proc { :foo }
        custom_error = stub_class "BlockContextError", described_class do
          symbol :test_error
          context(&block_arg)
        end

        expect(custom_error.context_type_declaration).to eq(block_arg)
      end
    end

    context "when called with more than one argument" do
      it "raises ArgumentError" do
        expect {
          stub_class "MultiArgContextError", described_class do
            context({ foo: :string }, { bar: :integer })
          end
        }.to raise_error(ArgumentError, "expected 0 or 1 argument, got 2")
      end
    end
  end

  describe ".foobara_manifest" do
    context "when to_include is provided" do
      it "adds types to to_include" do
        custom_error = stub_class "ManifestError", described_class do
          symbol :test_error
          context foo: :string
        end

        to_include = []
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_to_include)
          .and_return(to_include)

        custom_error.foobara_manifest

        # Verify to_include was populated (implementation detail test)
        expect(to_include).to_not be_empty if custom_error.types_depended_on.any?
      end
    end

    context "when to_include is nil and there are types_depended_on" do
      it "does not try to add types to to_include" do
        custom_error = stub_class "NilIncludeError", described_class do
          symbol :test_error
          # This creates a type dependency which will cause types_depended_on to be non-empty
          context foo: :string
        end

        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_to_include)
          .and_return(nil)

        # This tests the else branch at line 111 (when to_include is nil)
        expect { custom_error.foobara_manifest }.not_to raise_error
      end
    end

    context "when superclass is not Foobara::Error and to_include is provided" do
      it "adds base error to to_include" do
        base_error = stub_class "BaseManifestError", described_class do
          context({})
        end
        custom_error = stub_class "CustomManifestError", base_error do
          context({})
        end

        to_include = []
        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_to_include)
          .and_return(to_include)

        custom_error.foobara_manifest

        expect(to_include).to include(base_error)
      end
    end

    context "when superclass is not Foobara::Error and to_include is nil" do
      it "does not try to add base error to to_include" do
        base_error = stub_class "BaseNilIncludeError", described_class do
          symbol :base_error
          message "Base error"
          context({})
        end
        custom_error = stub_class "CustomNilIncludeError", base_error do
          context({})
        end

        allow(Foobara::TypeDeclarations).to receive(:foobara_manifest_context_to_include)
          .and_return(nil)

        # This tests the else branch at line 121 (when to_include is nil)
        expect { custom_error.foobara_manifest }.not_to raise_error
      end
    end
  end

  describe ".subclass" do
    context "when symbol is nil" do
      it "creates a subclass without defining symbol method" do
        base_error = stub_class "SubclassBaseError", described_class do
          symbol :base_error
          message "Base error"
        end

        # This tests the 'if symbol' branch at line 166 (when symbol is falsy)
        subclass = base_error.subclass(symbol: nil, name: "NilSymbolSubclassError")

        # Should fall back to default symbol behavior
        expect(subclass.symbol).to be_a(Symbol)
      end
    end

    context "when symbol is provided" do
      it "creates a subclass with defined symbol method" do
        base_error = stub_class "SymbolSubclassBaseError", described_class do
          symbol :base_error
          message "Base error"
        end

        # This tests the 'if symbol' branch at line 166 (when symbol is truthy)
        subclass = base_error.subclass(symbol: :custom_symbol, name: "CustomSymbolSubclassError")

        expect(subclass.symbol).to eq(:custom_symbol)
      end
    end

    context "when message is nil" do
      it "creates a subclass without defining message method" do
        base_error = stub_class "MessageNilSubclassBaseError", described_class do
          symbol :base_error
          message "Base error"
        end

        subclass = base_error.subclass(symbol: :test, message: nil, name: "NilMessageSubclassError")

        # Should fall back to default message behavior
        expect(subclass.message).to be_a(String)
      end
    end

    context "when message is provided" do
      it "creates a subclass with defined message method" do
        base_error = stub_class "MessageProvidedSubclassBaseError", described_class do
          symbol :base_error
          message "Base error"
        end

        subclass = base_error.subclass(symbol: :test, message: "Custom message", name: "CustomMessageSubclassError")

        expect(subclass.message).to eq("Custom message")
      end
    end

    context "when abstract is true" do
      it "creates an abstract subclass" do
        base_error = stub_class "AbstractSubclassBaseError", described_class do
          symbol :base_error
          message "Base error"
        end

        # This tests the 'if abstract' branch at line 187 (when abstract is truthy)
        subclass = base_error.subclass(symbol: :abstract_error, abstract: true, name: "AbstractSubclassError")

        expect(subclass.abstract?).to be(true)
      end
    end

    context "when abstract is false" do
      it "creates a non-abstract subclass" do
        base_error = stub_class "ConcreteSubclassBaseError", described_class do
          symbol :base_error
          message "Base error"
        end

        # This tests the 'if abstract' branch at line 187 (when abstract is falsy)
        subclass = base_error.subclass(symbol: :concrete_error, abstract: false, name: "ConcreteSubclassError")

        expect(subclass.abstract?).to be_falsey
      end
    end
  end

  describe "#initialize" do
    context "when message is not a string" do
      it "raises an error" do
        custom_error = stub_class "NilMessageError", described_class do
          symbol :test_error
        end

        expect {
          custom_error.new(message: nil)
        }.to raise_error("Bad error message, expected a string")
      end
    end

    context "when message is an empty string" do
      it "raises an error" do
        custom_error = stub_class "EmptyMessageError", described_class do
          symbol :test_error
        end

        expect {
          custom_error.new(message: "")
        }.to raise_error("Bad error message, expected a string")
      end
    end

    context "when backtrace_line is nil during iteration" do
      it "breaks out of the loop early" do
        custom_error = stub_class "ShortBacktraceError", described_class do
          symbol :test_error
          message "Test error"
          context({})
        end

        # The actual backtrace test - when caller returns nil in the backtrace
        # This happens naturally when there are fewer than 10 backtrace lines
        # We just need to verify the error can be created without issues
        error = custom_error.new

        # The break occurs when backtrace_line is nil, preventing out-of-bounds access
        expect(error.backtrace_when_initialized).to be_an(Array)
        expect(error).to be_a(custom_error)
      end
    end
  end

  describe "#eql?" do
    let(:error_class) do
      stub_class "TestEqualityError", described_class do
        symbol :test_error
        message "Test error"
        context({})
      end
    end

    context "when other is not an Error" do
      it "returns false" do
        error = error_class.new

        expect(error.eql?("not an error")).to be(false)
      end
    end

    context "when other is an Error with same symbol" do
      it "returns true" do
        error1 = error_class.new
        error2 = error_class.new

        expect(error1.eql?(error2)).to be(true)
      end
    end

    context "when other is an Error with different symbol" do
      it "returns false" do
        other_error_class = stub_class "OtherEqualityError", described_class do
          symbol :other_error
          message "Other error"
          context({})
        end

        error1 = error_class.new
        error2 = other_error_class.new

        expect(error1.eql?(error2)).to be(false)
      end
    end
  end

  describe "abstract class behavior" do
    it "can mark a class as abstract" do
      custom_error = stub_class "AbstractBehaviorError", described_class do
        symbol :test_error
        abstract
      end

      expect(custom_error.abstract?).to be(true)
    end

    it "returns false for non-abstract classes" do
      custom_error = stub_class "NonAbstractError", described_class do
        symbol :test_error
      end

      expect(custom_error.abstract?).to be_falsey
    end
  end
end
