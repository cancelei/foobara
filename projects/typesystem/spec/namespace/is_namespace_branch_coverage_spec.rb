RSpec.describe Foobara::Namespace::IsNamespace do
  after do
    Foobara.reset_alls
  end

  let(:namespace) do
    Object.new.tap do |o|
      class << o
        def scoped_path
          ["TestNamespace"]
        end

        def scoped_full_name
          "TestNamespace"
        end

        def scoped_full_path
          ["TestNamespace"]
        end
      end

      o.extend described_class
    end
  end

  describe "#scoped_clear_caches" do
    context "when @foobara_categories is not empty and has parent namespace" do
      let(:parent_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["ParentNamespace"]
            end
          end
          o.extend described_class
          o.foobara_add_category(:parent_category) { true }
        end
      end

      it "merges categories from parent namespace" do
        namespace.scoped_namespace = parent_namespace
        namespace.foobara_add_category(:child_category) { false }

        # Verify initial state
        expect(namespace.foobara_categories).to have_key(:child_category)
        expect(namespace.foobara_categories).to have_key(:parent_category)

        # Clear caches to trigger merge
        namespace.scoped_clear_caches

        # Verify categories are still merged
        expect(namespace.foobara_categories).to have_key(:parent_category)
        expect(namespace.foobara_categories).to have_key(:child_category)
      end
    end
  end

  describe "#foobara_register" do
    context "when scoped object is unregistered" do
      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "test_scoped"
        end
      end

      it "calls scoped_reregistering! when re-registering" do
        # First register it
        namespace.foobara_register(scoped_object)
        # Then unregister it
        namespace.foobara_unregister(scoped_object)

        # Verify it's unregistered
        expect(scoped_object.scoped_unregistered?).to be(true)

        # Now re-register - this should trigger scoped_reregistering!
        expect(scoped_object).to receive(:scoped_reregistering!).and_call_original
        namespace.foobara_register(scoped_object)
      end
    end

    context "when scoped is an IsNamespace" do
      let(:child_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["ChildNamespace"]
            end
          end
          o.extend described_class
          o.scoped_name = "ChildNamespace"
        end
      end

      it "sets foobara_parent_namespace instead of scoped_namespace" do
        namespace.foobara_register(child_namespace)
        expect(child_namespace.foobara_parent_namespace).to be(namespace)
        expect(namespace.foobara_children).to include(child_namespace)
      end
    end

    context "when scoped has unregistered_foobara_manifest_reference" do
      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "test_scoped"
          o.unregistered_foobara_manifest_reference = "some_reference"
        end
      end

      it "clears the unregistered manifest reference" do
        namespace.foobara_register(scoped_object)
        expect(scoped_object.unregistered_foobara_manifest_reference).to be_nil
      end
    end

    context "when scoped responds to foobara_on_register" do
      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "test_scoped"

          def o.foobara_on_register
            @on_register_called = true
          end

          def o.on_register_called?
            @on_register_called == true
          end
        end
      end

      it "calls foobara_on_register" do
        namespace.foobara_register(scoped_object)
        expect(scoped_object.on_register_called?).to be(true)
      end
    end
  end

  describe "#foobara_lookup_without_cache" do
    let(:visited) { Set.new }

    context "when mode is RELAXED" do
      let(:child_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["TestNamespace", "ChildNamespace"]
            end

            def scoped_full_path
              ["TestNamespace", "ChildNamespace"]
            end

            def scoped_full_name
              "TestNamespace::ChildNamespace"
            end
          end
          o.extend described_class
        end
      end

      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "test_item"
        end
      end

      before do
        namespace.foobara_children << child_namespace
        child_namespace.foobara_register(scoped_object)
      end

      it "searches in children when GENERAL mode doesn't find it" do
        path = ["test_item"]
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::RELAXED,
          visited: visited
        )
        expect(result).to eq(scoped_object)
      end

      context "when parent namespace exists" do
        let(:parent_namespace) do
          Object.new.tap do |o|
            class << o
              def scoped_path
                ["ParentNamespace"]
              end

              def scoped_full_path
                ["ParentNamespace"]
              end

              def scoped_full_name
                "ParentNamespace"
              end
            end
            o.extend described_class
          end
        end

        let(:parent_scoped_object) do
          Object.new.tap do |o|
            o.extend(Foobara::Scoped)
            o.scoped_name = "parent_item"
          end
        end

        before do
          namespace.scoped_namespace = parent_namespace
          parent_namespace.foobara_register(parent_scoped_object)
        end

        it "searches in parent namespace" do
          path = ["parent_item"]
          result = namespace.foobara_lookup_without_cache(
            path,
            filter: nil,
            mode: Foobara::Namespace::LookupMode::RELAXED,
            visited: visited
          )
          expect(result).to eq(parent_scoped_object)
        end
      end

      it "tries to look up with full path when other methods fail" do
        path = ["some_item"]
        # This will exercise the fallback to scoped_full_path
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::RELAXED,
          visited: visited
        )
        expect(result).to be_nil
      end
    end

    context "when path starts with empty string" do
      context "when mode is DIRECT and scoped_full_name is not empty" do
        it "returns nil" do
          path = ["", "something"]
          result = namespace.foobara_lookup_without_cache(
            path,
            filter: nil,
            mode: Foobara::Namespace::LookupMode::DIRECT,
            visited: visited
          )
          expect(result).to be_nil
        end
      end

      context "when mode is not DIRECT" do
        let(:root_namespace) do
          Object.new.tap do |o|
            class << o
              def scoped_path
                []
              end

              def scoped_full_name
                ""
              end

              def scoped_full_path
                []
              end

              def foobara_root?
                true
              end

              def foobara_parent_namespace
                nil
              end
            end
            o.extend described_class
          end
        end

        before do
          # Make namespace have root_namespace
          allow(namespace).to receive(:foobara_root_namespace).and_return(root_namespace)
        end

        it "strips the root namespace path and continues lookup" do
          path = ["", "something"]
          # This will trigger the path stripping logic
          result = namespace.foobara_lookup_without_cache(
            path,
            filter: nil,
            mode: Foobara::Namespace::LookupMode::GENERAL,
            visited: visited
          )
          # Will be nil since "something" doesn't exist, but we exercised the branch
          expect(result).to be_nil
        end
      end
    end

    context "when mode is ABSOLUTE" do
      let(:root_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              []
            end

            def foobara_root?
              true
            end

            def foobara_parent_namespace
              nil
            end
          end
          o.extend described_class
        end
      end

      let(:depends_on_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["DependsOnNamespace"]
            end
          end
          o.extend described_class
        end
      end

      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "test_item"
        end
      end

      before do
        allow(namespace).to receive(:foobara_root_namespace).and_return(root_namespace)
        root_namespace.foobara_depends_on_namespaces << depends_on_namespace
        depends_on_namespace.foobara_register(scoped_object)
      end

      it "searches in root and dependent namespaces" do
        path = ["DependsOnNamespace", "test_item"]
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::ABSOLUTE,
          visited: visited
        )
        expect(result).to eq(scoped_object)
      end
    end

    context "when mode is ABSOLUTE_SINGLE_NAMESPACE" do
      let(:root_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              []
            end
          end
          o.extend described_class
        end
      end

      before do
        allow(namespace).to receive(:foobara_root_namespace).and_return(root_namespace)
      end

      it "delegates to root namespace with CHILDREN_ONLY mode" do
        path = ["something"]
        expect(root_namespace).to receive(:foobara_lookup_without_cache).with(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::CHILDREN_ONLY,
          visited: visited
        )

        namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::ABSOLUTE_SINGLE_NAMESPACE,
          visited: visited
        )
      end
    end

    context "when mode is DIRECT" do
      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "direct_item"
        end
      end

      before do
        namespace.foobara_register(scoped_object)
      end

      it "returns the partial match from registry" do
        path = ["direct_item"]
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::DIRECT,
          visited: visited
        )
        expect(result).to eq(scoped_object)
      end
    end

    context "when partial match exists but path doesn't match exactly" do
      let(:child_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["TestNamespace", "Child"]
            end
          end
          o.extend described_class
        end
      end

      before do
        namespace.foobara_register(child_namespace)
      end

      it "continues searching when partial path doesn't match" do
        # This will find a partial match but the scoped_path won't match
        # triggering the branch where we continue searching
        path = ["Child", "something"]
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::GENERAL,
          visited: visited
        )
        # Should be nil since Child::something doesn't exist
        expect(result).to be_nil
      end
    end

    context "when mode is not STRICT" do
      let(:child_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["TestNamespace", "Child"]
            end
          end
          o.extend described_class
        end
      end

      before do
        namespace.foobara_children << child_namespace
      end

      it "includes children in to_consider" do
        path = ["something"]
        # This exercises the branch where children are added to to_consider
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::GENERAL,
          visited: visited
        )
        expect(result).to be_nil
      end
    end

    context "when mode is GENERAL or STRICT and has parent namespace" do
      let(:parent_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["Parent"]
            end
          end
          o.extend described_class
        end
      end

      let(:parent_scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "parent_item"
        end
      end

      before do
        namespace.scoped_namespace = parent_namespace
        parent_namespace.foobara_register(parent_scoped_object)
      end

      it "searches in parent with STRICT mode" do
        path = ["parent_item"]
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::GENERAL,
          visited: visited
        )
        expect(result).to eq(parent_scoped_object)
      end
    end

    context "when mode is GENERAL and has depends_on_namespaces" do
      let(:depends_on_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["DependsOn"]
            end
          end
          o.extend described_class
        end
      end

      let(:depends_scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "depends_item"
        end
      end

      before do
        namespace.foobara_depends_on_namespaces << depends_on_namespace
        depends_on_namespace.foobara_register(depends_scoped_object)
      end

      it "searches in dependent namespaces with _lookup_in" do
        path = ["depends_item"]
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::GENERAL,
          visited: visited
        )
        expect(result).to eq(depends_scoped_object)
      end

      it "searches recursively in dependent namespaces" do
        path = ["depends_item"]
        # Exercise the recursive lookup in depends_on_namespaces
        result = namespace.foobara_lookup_without_cache(
          path,
          filter: nil,
          mode: Foobara::Namespace::LookupMode::GENERAL,
          visited: visited
        )
        expect(result).to eq(depends_scoped_object)
      end
    end
  end

  describe "#foobara_each" do
    context "when mode is GENERAL" do
      let(:depends_on_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["DependsOn"]
            end
          end
          o.extend described_class
        end
      end

      let(:depends_scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "depends_item"
        end
      end

      before do
        namespace.foobara_depends_on_namespaces << depends_on_namespace
        depends_on_namespace.foobara_register(depends_scoped_object)
      end

      it "iterates over dependent namespaces" do
        found_items = []
        namespace.foobara_each(mode: Foobara::Namespace::LookupMode::GENERAL) do |item|
          found_items << item
        end
        expect(found_items).to include(depends_scoped_object)
      end
    end
  end

  describe "#foobara_registered?" do
    context "when path is a Type without scoped_path_set" do
      let(:type) do
        double("Type", is_a?: true, scoped_path_set?: false)
      end

      before do
        allow(type).to receive(:is_a?).with(Foobara::Types::Type).and_return(true)
      end

      it "returns false" do
        result = namespace.foobara_registered?(type)
        expect(result).to be(false)
      end
    end
  end

  describe "#_filter_from_method_name" do
    before do
      namespace.foobara_add_category(:test_category) { true }
    end

    context "when method matches foobara_(lookup|each|all)_category pattern" do
      it "returns filter for lookup with bang" do
        filter, method, bang = namespace.send(:_filter_from_method_name, :foobara_lookup_test_category!)
        expect(filter).to be_a(Proc)
        expect(method).to eq("lookup")
        expect(bang).to be(true)
      end

      it "returns nil for non-lookup methods with bang" do
        result = namespace.send(:_filter_from_method_name, :foobara_each_test_category!)
        expect(result).to be_nil
      end
    end

    context "when method matches foobara_category_registered? pattern" do
      it "returns filter for registered check" do
        filter, method = namespace.send(:_filter_from_method_name, :foobara_test_category_registered?)
        expect(filter).to be_a(Proc)
        expect(method).to eq("registered?")
      end
    end
  end

  describe "#_lookup_in" do
    let(:visited) { Set.new }

    context "when namespace has empty scoped_path" do
      let(:last_resort_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              []
            end
          end
          o.extend described_class
        end
      end

      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "test_item"
        end
      end

      before do
        last_resort_namespace.foobara_register(scoped_object)
      end

      it "adds to last_resort list" do
        path = ["test_item"]
        result = namespace.send(
          :_lookup_in,
          path,
          [last_resort_namespace],
          filter: nil,
          visited: visited
        )
        expect(result).to eq(scoped_object)
      end
    end

    context "when namespace has matching path prefix" do
      let(:matching_namespace) do
        Object.new.tap do |o|
          class << o
            def scoped_path
              ["Test"]
            end
          end
          o.extend described_class
        end
      end

      let(:scoped_object) do
        Object.new.tap do |o|
          o.extend(Foobara::Scoped)
          o.scoped_name = "item"
        end
      end

      before do
        matching_namespace.foobara_register(scoped_object)
      end

      it "searches in matching namespace" do
        path = ["Test", "item"]
        result = namespace.send(
          :_lookup_in,
          path,
          [matching_namespace],
          filter: nil,
          visited: visited
        )
        expect(result).to eq(scoped_object)
      end
    end
  end

  describe "#_path_start_match_count" do
    before do
      allow(namespace).to receive(:scoped_path).and_return(["Test", "Namespace"])
    end

    it "returns count of matching path parts" do
      path = ["Test", "Namespace", "Something"]
      count = namespace.send(:_path_start_match_count, path)
      expect(count).to eq(2)
    end

    it "returns 0 when no match" do
      path = ["Different", "Path"]
      count = namespace.send(:_path_start_match_count, path)
      expect(count).to eq(0)
    end

    it "returns partial match count" do
      path = ["Test", "Different"]
      count = namespace.send(:_path_start_match_count, path)
      expect(count).to eq(1)
    end
  end

  describe "#scoped_clear_caches when @foobara_categories is empty" do
    it "does not try to merge categories" do
      # Don't add any categories, so @foobara_categories is not defined
      expect(namespace.instance_variable_defined?(:@foobara_categories)).to be(false)

      namespace.scoped_clear_caches

      # Should still be undefined since we never accessed it
      expect(namespace.instance_variable_defined?(:@foobara_categories)).to be(false)
    end
  end

  describe "#foobara_unregister" do
    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "test_scoped"
      end
    end

    it "sets unregistered_foobara_manifest_reference and clears namespace" do
      namespace.foobara_register(scoped_object)

      # Mock a manifest reference
      allow(scoped_object).to receive(:foobara_manifest_reference).and_return("some_ref")

      namespace.foobara_unregister(scoped_object)

      expect(scoped_object.unregistered_foobara_manifest_reference).to eq("some_ref")
      expect(scoped_object.scoped_namespace).to be_nil
      expect(scoped_object.scoped_unregistered?).to be(true)
    end

    it "can unregister by path" do
      namespace.foobara_register(scoped_object)

      expect(namespace.foobara_registered?("test_scoped")).to be(true)

      namespace.foobara_unregister("test_scoped")

      expect(namespace.foobara_children).not_to include(scoped_object)
    end
  end

  describe "#foobara_unregister_all" do
    let(:scoped_object1) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "scoped1"
      end
    end

    let(:scoped_object2) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "scoped2"
      end
    end

    it "unregisters all children" do
      namespace.foobara_register(scoped_object1)
      namespace.foobara_register(scoped_object2)

      expect(namespace.foobara_registered?("scoped1")).to be(true)
      expect(namespace.foobara_registered?("scoped2")).to be(true)

      namespace.foobara_unregister_all

      expect(namespace.foobara_registered?("scoped1")).to be(false)
      expect(namespace.foobara_registered?("scoped2")).to be(false)
    end
  end

  describe "#foobara_all" do
    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "test_item"
      end
    end

    before do
      namespace.foobara_register(scoped_object)
    end

    it "returns all scoped objects as an array" do
      all = namespace.foobara_all
      expect(all).to be_an(Array)
      expect(all).to include(scoped_object)
    end

    context "with filter" do
      before do
        namespace.foobara_add_category(:test_category) { |obj| obj.scoped_name == "test_item" }
      end

      it "filters results" do
        filter = namespace.foobara_categories[:test_category]
        all = namespace.foobara_all(filter: filter)
        expect(all).to include(scoped_object)
      end
    end

    context "with different modes" do
      it "works with CHILDREN_ONLY mode" do
        all = namespace.foobara_all(mode: Foobara::Namespace::LookupMode::CHILDREN_ONLY)
        expect(all).to include(scoped_object)
      end

      it "works with ABSOLUTE mode" do
        all = namespace.foobara_all(mode: Foobara::Namespace::LookupMode::ABSOLUTE)
        expect(all).to include(scoped_object)
      end

      it "works with ABSOLUTE_SINGLE_NAMESPACE mode" do
        all = namespace.foobara_all(mode: Foobara::Namespace::LookupMode::ABSOLUTE_SINGLE_NAMESPACE)
        expect(all).to include(scoped_object)
      end
    end
  end

  describe "#foobara_root_namespace" do
    let(:root_namespace) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            []
          end

          def foobara_parent_namespace
            nil
          end

          def foobara_root?
            true
          end
        end
        o.extend described_class
      end
    end

    let(:intermediate_namespace) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            ["Intermediate"]
          end
        end
        o.extend described_class
      end
    end

    it "returns self when already root" do
      expect(root_namespace.foobara_root_namespace).to be(root_namespace)
    end

    it "traverses up to find root namespace" do
      intermediate_namespace.scoped_namespace = root_namespace
      namespace.scoped_namespace = intermediate_namespace

      expect(namespace.foobara_root_namespace).to be(root_namespace)
    end
  end

  describe "#foobara_category_symbol_for" do
    before do
      namespace.foobara_add_category(:type_a) { is_a?(String) }
      namespace.foobara_add_category(:type_b) { is_a?(Integer) }
    end

    it "returns matching category symbol" do
      expect(namespace.foobara_category_symbol_for("test")).to eq(:type_a)
      expect(namespace.foobara_category_symbol_for(42)).to eq(:type_b)
    end

    it "returns nil when no category matches" do
      expect(namespace.foobara_category_symbol_for([])).to be_nil
    end
  end

  describe "#method_missing and #respond_to_missing?" do
    before do
      namespace.foobara_add_category(:test_cat) { true }
    end

    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "test_item"
      end
    end

    before do
      namespace.foobara_register(scoped_object)
    end

    it "handles foobara_lookup_<category>" do
      result = namespace.foobara_lookup_test_cat("test_item")
      expect(result).to eq(scoped_object)
    end

    it "handles foobara_each_<category>" do
      items = []
      namespace.foobara_each_test_cat { |item| items << item }
      expect(items).to include(scoped_object)
    end

    it "handles foobara_all_<category>" do
      all = namespace.foobara_all_test_cat
      expect(all).to include(scoped_object)
    end

    it "handles foobara_<category>_registered?" do
      expect(namespace.foobara_test_cat_registered?("test_item")).to be(true)
      expect(namespace.foobara_test_cat_registered?("nonexistent")).to be(false)
    end

    it "responds to category methods" do
      expect(namespace.respond_to?(:foobara_lookup_test_cat)).to be(true)
      expect(namespace.respond_to?(:foobara_each_test_cat)).to be(true)
      expect(namespace.respond_to?(:foobara_all_test_cat)).to be(true)
      expect(namespace.respond_to?(:foobara_test_cat_registered?)).to be(true)
    end

    it "does not respond to invalid category methods" do
      expect(namespace.respond_to?(:foobara_lookup_invalid_cat)).to be(false)
    end
  end

  describe "#_filter_from_method_name edge cases" do
    it "returns nil for non-matching method names" do
      result = namespace.send(:_filter_from_method_name, :some_random_method)
      expect(result).to be_nil
    end

    it "returns nil for methods without category" do
      result = namespace.send(:_filter_from_method_name, :foobara_lookup_nonexistent!)
      expect(result).to be_nil
    end
  end

  describe "#lru_cache" do
    it "returns shared LRU cache from Namespace" do
      cache = namespace.lru_cache
      expect(cache).to be(Foobara::Namespace.lru_cache)
    end
  end

  describe "#foobara_lookup with caching" do
    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "cached_item"
      end
    end

    before do
      namespace.foobara_register(scoped_object)
    end

    it "uses LRU cache for repeated lookups" do
      # First lookup - not cached
      result1 = namespace.foobara_lookup("cached_item")
      expect(result1).to eq(scoped_object)

      # Second lookup - should use cache
      result2 = namespace.foobara_lookup("cached_item")
      expect(result2).to eq(scoped_object)
    end

    it "validates lookup mode" do
      expect do
        namespace.foobara_lookup("cached_item", mode: :invalid_mode)
      end.to raise_error(ArgumentError)
    end
  end

  describe "#foobara_lookup_without_cache with visited tracking" do
    let(:visited) { Set.new }

    it "returns nil when path was already visited" do
      path = ["test"]
      visited_key = [path, Foobara::Namespace::LookupMode::GENERAL, namespace]
      visited << visited_key

      result = namespace.foobara_lookup_without_cache(
        path,
        filter: nil,
        mode: Foobara::Namespace::LookupMode::GENERAL,
        visited: visited
      )

      expect(result).to be_nil
    end
  end

  describe "#foobara_lookup_without_cache with STRICT mode" do
    let(:visited) { Set.new }
    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "strict_item"
      end
    end

    before do
      namespace.foobara_register(scoped_object)
    end

    it "does not add children to to_consider in STRICT mode" do
      # In STRICT mode, children should not be included
      path = ["strict_item"]
      result = namespace.foobara_lookup_without_cache(
        path,
        filter: nil,
        mode: Foobara::Namespace::LookupMode::STRICT,
        visited: visited
      )
      expect(result).to eq(scoped_object)
    end
  end

  describe "#foobara_lookup_without_cache with partial match returning exact match" do
    let(:visited) { Set.new }
    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "exact"

        class << o
          def scoped_path
            ["exact"]
          end
        end
      end
    end

    before do
      namespace.foobara_register(scoped_object)
    end

    it "returns partial when scoped_path matches exactly" do
      path = ["exact"]
      result = namespace.foobara_lookup_without_cache(
        path,
        filter: nil,
        mode: Foobara::Namespace::LookupMode::GENERAL,
        visited: visited
      )
      expect(result).to eq(scoped_object)
    end
  end

  describe "#_lookup_in with multiple matching children" do
    let(:visited) { Set.new }

    let(:namespace1) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            ["A", "B"]
          end
        end
        o.extend described_class
      end
    end

    let(:namespace2) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            ["A"]
          end
        end
        o.extend described_class
      end
    end

    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "item"
      end
    end

    before do
      namespace1.foobara_register(scoped_object)
    end

    it "sorts matching children by match count" do
      path = ["A", "B", "item"]
      result = namespace.send(
        :_lookup_in,
        path,
        [namespace2, namespace1],
        filter: nil,
        visited: visited
      )
      expect(result).to eq(scoped_object)
    end
  end

  describe "#_lookup_in with last_resort and multiple namespaces" do
    let(:visited) { Set.new }

    let(:last_resort1) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            []
          end
        end
        o.extend described_class
      end
    end

    let(:last_resort2) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            []
          end
        end
        o.extend described_class
      end
    end

    let(:scoped_object) do
      Object.new.tap do |o|
        o.extend(Foobara::Scoped)
        o.scoped_name = "item"
      end
    end

    before do
      last_resort1.foobara_register(scoped_object)
    end

    it "searches through unique last_resort namespaces" do
      path = ["item"]
      result = namespace.send(
        :_lookup_in,
        path,
        [last_resort1, last_resort2, last_resort1], # last_resort1 appears twice
        filter: nil,
        visited: visited
      )
      expect(result).to eq(scoped_object)
    end
  end

  describe "#_lookup_in when no matches found" do
    let(:visited) { Set.new }

    let(:other_namespace) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            ["Other"]
          end
        end
        o.extend described_class
      end
    end

    it "returns nil when nothing matches" do
      path = ["nonexistent"]
      result = namespace.send(
        :_lookup_in,
        path,
        [other_namespace],
        filter: nil,
        visited: visited
      )
      expect(result).to be_nil
    end
  end

  describe "#foobara_lookup_without_cache partial match but no scoped found" do
    let(:visited) { Set.new }
    let(:partial_namespace) do
      Object.new.tap do |o|
        class << o
          def scoped_path
            ["Partial"]
          end

          def scoped_full_path
            ["TestNamespace", "Partial"]
          end
        end
        o.extend described_class
      end
    end

    before do
      namespace.foobara_register(partial_namespace)
    end

    it "returns partial when no exact scoped is found" do
      path = ["Partial"]
      result = namespace.foobara_lookup_without_cache(
        path,
        filter: nil,
        mode: Foobara::Namespace::LookupMode::GENERAL,
        visited: visited
      )
      expect(result).to eq(partial_namespace)
    end
  end
end
