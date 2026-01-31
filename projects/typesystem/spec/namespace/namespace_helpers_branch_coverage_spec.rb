RSpec.describe Foobara::Namespace::NamespaceHelpers do
  after do
    Foobara.reset_alls
  end

  describe ".initialize_foobara_namespace" do
    let(:namespace) do
      Object.new.tap do |o|
        o.extend Foobara::Scoped
        o.extend Foobara::Namespace::IsNamespace
      end
    end

    context "when scoped_name_or_path is a Symbol" do
      it "converts symbol to string and sets scoped_name" do
        Foobara::Namespace::NamespaceHelpers.initialize_foobara_namespace(
          namespace,
          :test_name
        )
        expect(namespace.scoped_name).to eq("test_name")
      end
    end

    context "when scoped_name_or_path is a String" do
      it "sets scoped_name" do
        Foobara::Namespace::NamespaceHelpers.initialize_foobara_namespace(
          namespace,
          "test_name"
        )
        expect(namespace.scoped_name).to eq("test_name")
      end
    end

    context "when scoped_name_or_path is an Array" do
      it "sets scoped_path" do
        Foobara::Namespace::NamespaceHelpers.initialize_foobara_namespace(
          namespace,
          ["Test", "Path"]
        )
        expect(namespace.scoped_path).to eq(["Test", "Path"])
      end
    end

    context "when scoped_path is already set" do
      it "does not override existing path" do
        namespace.scoped_path = ["Existing", "Path"]

        Foobara::Namespace::NamespaceHelpers.initialize_foobara_namespace(
          namespace,
          "new_name"
        )

        expect(namespace.scoped_path).to eq(["Existing", "Path"])
      end
    end

    context "when scoped_path is set and parent_namespace provided" do
      let(:parent_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["Parent"]
            end
          end
          o.extend Foobara::Namespace::IsNamespace
        end
      end

      it "sets parent namespace" do
        namespace.scoped_name = "child"

        Foobara::Namespace::NamespaceHelpers.initialize_foobara_namespace(
          namespace,
          parent_namespace: parent_namespace
        )

        expect(namespace.foobara_parent_namespace).to eq(parent_namespace)
      end
    end

    context "when scoped_path is not set but parent_namespace provided" do
      let(:parent_namespace) do
        Object.new.tap do |o|
          o.extend Foobara::Namespace::IsNamespace
        end
      end

      it "does not set parent namespace" do
        Foobara::Namespace::NamespaceHelpers.initialize_foobara_namespace(
          namespace,
          parent_namespace: parent_namespace
        )

        expect(namespace.foobara_parent_namespace).to be_nil
      end
    end
  end

  describe ".foobara_namespace!" do
    let(:object) do
      Object.new
    end

    it "extends object with Scoped and IsNamespace" do
      Foobara::Namespace::NamespaceHelpers.foobara_namespace!(object)

      expect(object).to be_a(Foobara::Scoped)
      expect(object).to be_a(Foobara::Namespace::IsNamespace)
    end

    context "when ignore_modules is provided" do
      it "sets scoped_ignore_modules" do
        test_module = Module.new
        Foobara::Namespace::NamespaceHelpers.foobara_namespace!(
          object,
          ignore_modules: [test_module]
        )

        expect(object.instance_variable_get(:@scoped_ignore_modules)).to eq([test_module])
      end
    end

    context "when scoped_path is provided" do
      it "sets scoped_path" do
        Foobara::Namespace::NamespaceHelpers.foobara_namespace!(
          object,
          scoped_path: ["Test", "Path"]
        )

        expect(object.scoped_path).to eq(["Test", "Path"])
      end
    end

    context "when scoped_path is set" do
      it "calls update_children_with_new_parent" do
        expect(Foobara::Namespace::NamespaceHelpers).to receive(:update_children_with_new_parent)
          .with(object)

        Foobara::Namespace::NamespaceHelpers.foobara_namespace!(
          object,
          scoped_path: ["Parent"]
        )
      end
    end
  end

  describe ".foobara_autoset_namespace" do
    let(:mod) do
      Module.new.tap { |m| m.extend Foobara::Scoped }
    end

    context "when mod already has scoped_namespace" do
      let(:existing_namespace) do
        Object.new.tap { |o| o.extend Foobara::Namespace::IsNamespace }
      end

      it "returns early without changing namespace" do
        mod.scoped_namespace = existing_namespace

        Foobara::Namespace::NamespaceHelpers.foobara_autoset_namespace(mod)

        expect(mod.scoped_namespace).to eq(existing_namespace)
      end
    end

    context "when parent module is a namespace" do
      let(:parent_module) do
        Module.new.tap do |m|
          m.extend Foobara::Scoped
          m.extend Foobara::Namespace::IsNamespace
        end
      end

      it "sets parent as namespace" do
        allow(Foobara::Util).to receive(:module_for).with(mod).and_return(parent_module)

        Foobara::Namespace::NamespaceHelpers.foobara_autoset_namespace(mod)

        expect(mod.scoped_namespace).to eq(parent_module)
      end
    end

    context "when parent module is not a namespace" do
      let(:non_namespace_parent) do
        Module.new
      end

      let(:grandparent_namespace) do
        Module.new.tap do |m|
          m.extend Foobara::Scoped
          m.extend Foobara::Namespace::IsNamespace
        end
      end

      it "traverses up to find namespace" do
        allow(Foobara::Util).to receive(:module_for).with(mod).and_return(non_namespace_parent)
        allow(Foobara::Util).to receive(:module_for).with(non_namespace_parent).and_return(grandparent_namespace)

        Foobara::Namespace::NamespaceHelpers.foobara_autoset_namespace(mod)

        expect(mod.scoped_namespace).to eq(grandparent_namespace)
      end
    end

    context "when no parent namespace found but default_namespace provided" do
      it "uses default_namespace" do
        default_ns = Object.new.tap { |o| o.extend Foobara::Namespace::IsNamespace }

        allow(Foobara::Util).to receive(:module_for).with(mod).and_return(nil)

        Foobara::Namespace::NamespaceHelpers.foobara_autoset_namespace(
          mod,
          default_namespace: default_ns
        )

        expect(mod.scoped_namespace).to eq(default_ns)
      end
    end
  end

  describe ".anon_sequence" do
    it "returns incrementing sequence for class name" do
      # Reset sequences to get predictable values
      Foobara::Namespace::NamespaceHelpers.instance_variable_set(:@anon_sequences, {})

      seq1 = Foobara::Namespace::NamespaceHelpers.anon_sequence("TestClass")
      seq2 = Foobara::Namespace::NamespaceHelpers.anon_sequence("TestClass")
      seq3 = Foobara::Namespace::NamespaceHelpers.anon_sequence("OtherClass")

      expect(seq1).to eq(1)
      expect(seq2).to eq(2)
      expect(seq3).to eq(1)
    end
  end

  describe ".update_children_with_new_parent" do
    context "when mod has empty scoped_full_path" do
      let(:mod) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = []
        end
      end

      it "returns early without processing" do
        expect {
          Foobara::Namespace::NamespaceHelpers.update_children_with_new_parent(mod)
        }.not_to raise_error
      end
    end

    context "when children need to be moved" do
      let(:root_namespace) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = []
        end
      end

      let(:new_parent) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = ["New", "Parent"]
        end
      end

      let(:child) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.scoped_path = ["New", "Parent", "Child"]
        end
      end

      before do
        allow(Foobara).to receive(:foobara_root_namespace).and_return(root_namespace)
        root_namespace.foobara_register(child)
      end

      it "moves matching children to new parent" do
        Foobara::Namespace::NamespaceHelpers.update_children_with_new_parent(new_parent)

        # Child should have been moved to new_parent
        expect(new_parent.foobara_registered?("Child")).to be(true)
      end
    end

    context "when child is the mod itself" do
      let(:root_namespace) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = []
        end
      end

      let(:mod) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = ["Mod"]
        end
      end

      before do
        allow(Foobara).to receive(:foobara_root_namespace).and_return(root_namespace)
        root_namespace.foobara_register(mod)
      end

      it "skips the mod itself" do
        expect {
          Foobara::Namespace::NamespaceHelpers.update_children_with_new_parent(mod)
        }.not_to raise_error
      end
    end

    context "when child parent path starts with mod path" do
      let(:root_namespace) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = []
        end
      end

      let(:mod) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = ["A"]
        end
      end

      let(:parent) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = ["A", "B"]
        end
      end

      let(:child) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.scoped_path = ["C"]
        end
      end

      before do
        allow(Foobara).to receive(:foobara_root_namespace).and_return(root_namespace)
        root_namespace.foobara_register(parent)
        parent.foobara_register(child)
      end

      it "skips children whose parent path starts with mod path" do
        expect {
          Foobara::Namespace::NamespaceHelpers.update_children_with_new_parent(mod)
        }.not_to raise_error
      end
    end

    context "when child has same scoped_full_path as mod" do
      let(:root_namespace) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = []
        end
      end

      let(:mod) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = ["Same"]
        end
      end

      let(:child) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.scoped_path = ["Same"]
        end
      end

      before do
        allow(Foobara).to receive(:foobara_root_namespace).and_return(root_namespace)
        root_namespace.foobara_register(child)
      end

      it "skips child with same path" do
        expect {
          Foobara::Namespace::NamespaceHelpers.update_children_with_new_parent(mod)
        }.not_to raise_error
      end
    end

    context "when child has no parent" do
      let(:root_namespace) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = []
        end
      end

      let(:mod) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.extend Foobara::Namespace::IsNamespace
          o.scoped_path = ["Mod"]
        end
      end

      let(:child) do
        Object.new.tap do |o|
          o.extend Foobara::Scoped
          o.scoped_path = ["Mod", "Child"]
        end
      end

      before do
        allow(Foobara).to receive(:foobara_root_namespace).and_return(root_namespace)
        root_namespace.foobara_register(child)
      end

      it "adjusts path and registers with mod" do
        Foobara::Namespace::NamespaceHelpers.update_children_with_new_parent(mod)

        # Child should now be registered under mod with relative path
        expect(child.scoped_path).to eq(["Child"])
      end
    end
  end

  describe "instance methods delegation" do
    let(:test_object) do
      Object.new.tap { |o| o.extend Foobara::Namespace::NamespaceHelpers }
    end

    describe "#foobara_namespace!" do
      it "delegates to class method" do
        test_object.foobara_namespace!(scoped_path: ["Test"])

        expect(test_object).to be_a(Foobara::Namespace::IsNamespace)
        expect(test_object.scoped_path).to eq(["Test"])
      end
    end

    describe "#foobara_root_namespace!" do
      it "calls foobara_namespace! with empty path" do
        test_module = Module.new
        test_object.foobara_root_namespace!(ignore_modules: [test_module])

        expect(test_object).to be_a(Foobara::Namespace::IsNamespace)
        expect(test_object.scoped_path).to eq([])
      end
    end

    describe "#foobara_autoset_namespace!" do
      it "delegates to class method" do
        namespace = Object.new.tap { |o| o.extend Foobara::Namespace::IsNamespace }
        mod = Module.new.tap { |m| m.extend Foobara::Namespace::NamespaceHelpers; m.extend Foobara::Scoped }

        # Mock module_for to return nil so default_namespace is used
        allow(Foobara::Util).to receive(:module_for).with(mod).and_return(nil)

        mod.foobara_autoset_namespace!(default_namespace: namespace)

        expect(mod.scoped_namespace).to eq(namespace)
      end
    end

    describe "#foobara_autoset_scoped_path!" do
      it "delegates to class method" do
        test_object.extend Foobara::Scoped
        test_object.scoped_name = "Test"

        # Make sure it doesn't hang
        allow(Foobara::Namespace::NamespaceHelpers).to receive(:foobara_autoset_scoped_path)

        test_object.foobara_autoset_scoped_path!(make_top_level: true)

        expect(Foobara::Namespace::NamespaceHelpers).to have_received(:foobara_autoset_scoped_path)
          .with(test_object, make_top_level: true)
      end
    end
  end
end
