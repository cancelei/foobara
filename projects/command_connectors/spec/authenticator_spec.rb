RSpec.describe Foobara::CommandConnector::Authenticator do
  after do
    Foobara.reset_alls
  end

  describe ".subclass" do
    context "when all parameters are provided" do
      it "sets the default symbol, explanation, and block" do
        test_block = proc { "authenticated" }
        klass = described_class.subclass(
          to: :string,
          symbol: :custom_auth,
          explanation: "Custom authentication",
          &test_block
        )

        expect(klass.default_symbol).to eq(:custom_auth)
        expect(klass.default_explanation).to eq("Custom authentication")
        expect(klass.default_block).to eq(test_block)
      end
    end

    context "when symbol is not provided" do
      it "does not set a default symbol" do
        klass = described_class.subclass(
          to: :string,
          explanation: "Some explanation"
        )

        # For anonymous classes, default_symbol will be nil
        # This tests the condition at line 11 (symbol is falsy, so the else branch is taken)
        expect(klass.default_symbol).to be_nil
        expect(klass.default_explanation).to eq("Some explanation")
      end
    end

    context "when explanation is not provided" do
      it "uses the default explanation" do
        klass = described_class.subclass(
          to: :string,
          symbol: :test_auth
        )

        expect(klass.default_symbol).to eq(:test_auth)
        expect(klass.default_explanation).to be_nil
      end
    end

    context "when block is not provided" do
      it "does not set a default block" do
        klass = described_class.subclass(
          to: :string,
          symbol: :test_auth,
          explanation: "Test"
        )

        expect(klass.default_block).to be_nil
      end
    end
  end

  describe ".default_symbol" do
    context "when @default_symbol is already set" do
      it "returns the set symbol" do
        klass = described_class.subclass(to: :string, symbol: :preset_symbol)
        expect(klass.default_symbol).to eq(:preset_symbol)
      end
    end

    context "when @default_symbol is not set" do
      it "attempts to derive symbol from class name" do
        klass = described_class.subclass(to: :string)
        # For anonymous classes, this will return nil since
        # Util.non_full_name_underscore returns nil
        # This tests the else branch at line 19
        expect(klass.default_symbol).to be_nil
      end
    end
  end

  describe "#authenticate" do
    let(:request) { instance_double(Foobara::CommandConnector::Request) }
    let(:authenticator) { described_class.new(symbol: :test_auth) { true } }

    context "when request is applicable" do
      before do
        allow(authenticator).to receive(:applicable?).with(request).and_return(true)
        allow(authenticator).to receive(:process_value!).with(request)
      end

      it "processes the request" do
        authenticator.authenticate(request)
        expect(authenticator).to have_received(:process_value!).with(request)
      end
    end

    context "when request is not applicable" do
      before do
        allow(authenticator).to receive(:applicable?).with(request).and_return(false)
        allow(authenticator).to receive(:process_value!)
      end

      it "does not process the request" do
        authenticator.authenticate(request)
        expect(authenticator).not_to have_received(:process_value!)
      end
    end
  end

  describe "#initialize" do
    context "with custom symbol and explanation" do
      it "uses the provided values" do
        block = proc { "test" }
        authenticator = described_class.new(
          symbol: :custom,
          explanation: "Custom explanation",
          &block
        )

        expect(authenticator.symbol).to eq(:custom)
        expect(authenticator.explanation).to eq("Custom explanation")
        expect(authenticator.block).to eq(block)
      end
    end

    context "without symbol" do
      it "uses the class default symbol" do
        klass = described_class.subclass(to: :string, symbol: :class_default)
        authenticator = klass.new(explanation: "Test")

        expect(authenticator.symbol).to eq(:class_default)
      end
    end

    context "without explanation" do
      it "uses the class default explanation or symbol" do
        klass = described_class.subclass(to: :string, symbol: :test_auth, explanation: "Default explanation")
        authenticator = klass.new

        expect(authenticator.explanation).to eq("Default explanation")
      end
    end

    context "without block" do
      it "uses the class default block" do
        test_block = proc { "default" }
        klass = described_class.subclass(to: :string, &test_block)
        authenticator = klass.new(symbol: :test)

        expect(authenticator.block).to eq(test_block)
      end
    end
  end

  describe "#transform" do
    let(:request) { instance_double(Foobara::CommandConnector::Request) }
    let(:authenticator) { described_class.new(symbol: :test) { "authenticated_user" } }

    it "executes the block in the context of the request" do
      allow(request).to receive(:instance_exec).and_yield.and_return("authenticated_user")

      result = authenticator.transform(request)

      expect(request).to have_received(:instance_exec)
    end
  end

  describe "#to_proc" do
    it "returns the authenticator block" do
      test_block = proc { "test" }
      authenticator = described_class.new(symbol: :test, &test_block)

      expect(authenticator.to_proc).to eq(test_block)
    end
  end
end
