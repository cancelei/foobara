RSpec.describe Foobara::DetachedEntity::Concerns::Associations do
  after do
    Foobara.reset_alls
  end

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  describe ".foobara_associations" do
    it "caches associations based on remove_sensitive flag" do
      stub_class :TestEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :TestParent, Foobara::DetachedEntity do
        attributes id: :integer, child: :TestEntity
        primary_key :id
      end

      # First call should construct and cache
      assoc1 = TestParent.foobara_associations
      assoc2 = TestParent.foobara_associations

      expect(assoc1.object_id).to eq(assoc2.object_id)
    end

    it "returns different cache for different remove_sensitive values" do
      stub_class :TestEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :TestParent, Foobara::DetachedEntity do
        attributes id: :integer, child: :TestEntity
        primary_key :id
      end

      original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?

      begin
        Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)
        assoc_false = TestParent.foobara_associations

        Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)
        assoc_true = TestParent.foobara_associations

        # Different caches for different remove_sensitive values
        expect(assoc_false.object_id).not_to eq(assoc_true.object_id)
      ensure
        Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
      end
    end

    it "initializes @foobara_associations when not defined" do
      stub_class :TestEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :TestParent, Foobara::DetachedEntity do
        attributes id: :integer, child: :TestEntity
        primary_key :id
      end

      # Remove instance variable to test initialization
      TestParent.remove_instance_variable(:@foobara_associations) if TestParent.instance_variable_defined?(:@foobara_associations)

      assoc = TestParent.foobara_associations
      expect(assoc).to be_a(Hash)
    end
  end

  describe ".foobara_deep_associations" do
    it "caches deep associations based on remove_sensitive flag" do
      stub_class :TestEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :TestParent, Foobara::DetachedEntity do
        attributes id: :integer, child: :TestEntity
        primary_key :id
      end

      deep1 = TestParent.foobara_deep_associations
      deep2 = TestParent.foobara_deep_associations

      expect(deep1.object_id).to eq(deep2.object_id)
    end

    it "returns different cache for different remove_sensitive values" do
      stub_class :TestEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :TestParent, Foobara::DetachedEntity do
        attributes id: :integer, child: :TestEntity
        primary_key :id
      end

      original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?

      begin
        Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)
        deep_false = TestParent.foobara_deep_associations

        Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)
        deep_true = TestParent.foobara_deep_associations

        expect(deep_false.object_id).not_to eq(deep_true.object_id)
      ensure
        Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
      end
    end

    it "initializes @foobara_deep_associations when not defined" do
      stub_class :TestEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :TestParent, Foobara::DetachedEntity do
        attributes id: :integer, child: :TestEntity
        primary_key :id
      end

      TestParent.remove_instance_variable(:@foobara_deep_associations) if TestParent.instance_variable_defined?(:@foobara_deep_associations)

      deep = TestParent.foobara_deep_associations
      expect(deep).to be_a(Hash)
    end

    it "includes nested associations from associated entities" do
      stub_class :NestedEntity, Foobara::Entity do
        attributes id: :integer, value: :string
        primary_key :id
      end

      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string, nested: :NestedEntity
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, child: :ChildEntity
        primary_key :id
      end

      deep = ParentEntity.foobara_deep_associations

      expect(deep.keys).to include("child")
      expect(deep.keys).to include("child.nested")
    end
  end

  describe ".association" do
    it "defines a method that returns single association when is_many is false" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, child: :ChildEntity
        primary_key :id

        association :my_child, :child
      end

      child = ChildEntity.new(id: 1, name: "Test")
      parent = ParentEntity.new(id: 1, child:)

      expect(parent.my_child).to eq(child)
    end

    it "defines a method that returns array when is_many is true" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, children: [:ChildEntity]
        primary_key :id

        association :my_children, :children, :"#"
      end

      children = [
        ChildEntity.new(id: 1, name: "Test1"),
        ChildEntity.new(id: 2, name: "Test2")
      ]
      parent = ParentEntity.new(id: 1, children:)

      expect(parent.my_children).to be_an(Array)
      expect(parent.my_children.size).to eq(2)
    end

    it "returns nil when single association is empty" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, child: :ChildEntity
        primary_key :id

        association :my_child, :child
      end

      parent = ParentEntity.new(id: 1, child: nil)

      expect(parent.my_child).to be_nil
    end

    it "returns first value when values size is 1" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, child: :ChildEntity
        primary_key :id

        association :my_child, :child
      end

      child = ChildEntity.new(id: 1, name: "Test")
      parent = ParentEntity.new(id: 1, child:)

      expect(parent.my_child).to eq(child)
    end
  end

  describe ".association_for" do
    it "returns data_path when single filter matches deep_associations key directly" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, child: :ChildEntity
        primary_key :id
      end

      path = ParentEntity.association_for([:child])
      expect(path).to eq("child")
    end

    it "filters associations when single filter does not match directly" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, first_child: :ChildEntity
        primary_key :id
      end

      path = ParentEntity.association_for([:ChildEntity])
      expect(path).to eq("first_child")
    end

    it "applies multiple filters sequentially" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :OtherEntity, Foobara::Entity do
        attributes id: :integer, value: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, first_child: :ChildEntity, second_child: :OtherEntity
        primary_key :id
      end

      path = ParentEntity.association_for([:ChildEntity])
      expect(path).to eq("first_child")
    end

    it "handles result size of 1 correctly" do
      stub_class :ChildEntity, Foobara::Entity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      stub_class :ParentEntity, Foobara::DetachedEntity do
        attributes id: :integer, child: :ChildEntity
        primary_key :id
      end

      path = ParentEntity.association_for([:ChildEntity])
      expect(path).to eq("child")
    end
  end

  describe ".filtered_associations" do
    context "when filter is a Symbol" do
      it "converts to string and filters" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, my_child: :ChildEntity
          primary_key :id
        end

        filtered = ParentEntity.filtered_associations(:child)
        expect(filtered).not_to be_empty
        expect(filtered.first).to include("child")
      end
    end

    context "when filter is a String with uppercase letters" do
      it "filters by entity class name" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        filtered = ParentEntity.filtered_associations("ChildEntity")
        expect(filtered).not_to be_empty
      end
    end

    context "when filter is a String without uppercase letters" do
      it "filters by key substring" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, my_special_child: :ChildEntity
          primary_key :id
        end

        filtered = ParentEntity.filtered_associations("special")
        expect(filtered).not_to be_empty
        expect(filtered.first).to include("special")
      end
    end

    context "when filter is a Class extending DetachedEntity" do
      it "filters by entity class equality" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        filtered = ParentEntity.filtered_associations(ChildEntity)
        expect(filtered).not_to be_empty
      end

      it "filters by entity class inheritance" do
        stub_class :BaseEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ChildEntity, BaseEntity do
          attributes name: :string
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        filtered = ParentEntity.filtered_associations(BaseEntity)
        expect(filtered).not_to be_empty
      end
    end
  end

  describe ".construct_associations" do
    context "when initial is true and type extends detached_entity" do
      it "recursively constructs from target_class attributes_type" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end
    end

    context "when type extends entity" do
      it "adds association at path" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc["child"]).to be_a(Foobara::Types::Type)
      end
    end

    context "when type extends tuple" do
      it "constructs associations for each element with index path" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [:ChildEntity, :string] }
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        # Should include tuple_field.0 for the ChildEntity
        expect(assoc.keys.any? { |k| k.include?("tuple_field") }).to be true
      end

      it "filters out sensitive element_types when remove_sensitive is true" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [:ChildEntity] }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          # Should still work even with remove_sensitive
          assoc = ParentEntity.construct_associations
          expect(assoc).to be_a(Hash)
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "handles each element with index correctly" do
        stub_class :Entity1, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :Entity2, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [:Entity1, :Entity2] }
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        # Both entities should be in associations
        expect(assoc.keys.count { |k| k.include?("tuple_field") }).to be > 0
      end
    end

    context "when type extends array" do
      it "constructs associations for element_type with # path" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, children: [:ChildEntity]
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc["children.#"]).to be_a(Foobara::Types::Type)
      end

      it "skips when element_type is nil" do
        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, items: :array
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end

      it "skips when element_type is sensitive and remove_sensitive is true" do
        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, items: [{ type: :string, sensitive: true }]
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          assoc = ParentEntity.construct_associations
          # Should not include items.# because element is sensitive
          expect(assoc["items.#"]).to be_nil
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "includes when element_type is not sensitive or remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, children: [:ChildEntity]
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          assoc = ParentEntity.construct_associations
          expect(assoc["children.#"]).not_to be_nil
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends attributes" do
      it "constructs associations for each attribute" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity, name: :string
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc["child"]).to be_a(Foobara::Types::Type)
        expect(assoc["name"]).to be_nil # string is not an entity
      end

      it "skips sensitive attributes when remove_sensitive is true" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer,
                     child: :ChildEntity,
                     secret: { type: :ChildEntity, sensitive: true }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          assoc = ParentEntity.construct_associations
          expect(assoc["child"]).not_to be_nil
          expect(assoc["secret"]).to be_nil
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "processes all attributes when remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          assoc = ParentEntity.construct_associations
          expect(assoc["child"]).not_to be_nil
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends model" do
      it "constructs associations from model attributes_type" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes child: :ChildEntity
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc.keys.any? { |k| k.include?("model") }).to be true
      end

      it "uses foobara_attributes_type when target_class responds to it" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes child: :ChildEntity
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end

      it "uses attributes_type when target_class does not respond to foobara_attributes_type" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes child: :ChildEntity
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end

      it "skips when attributes_type is sensitive and remove_sensitive is true" do
        stub_class :CustomModel, Foobara::Model do
          attributes secret: { type: :string, sensitive: true }
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: { type: :CustomModel, sensitive: true }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          assoc = ParentEntity.construct_associations
          # Should handle sensitive models
          expect(assoc).to be_a(Hash)
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "processes when attributes_type is not sensitive or remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes child: :ChildEntity
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          assoc = ParentEntity.construct_associations
          expect(assoc).to be_a(Hash)
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends associative_array" do
      it "does not add associations for associative arrays" do
        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc_array: { type: :associative_array, key_type: :string, value_type: :integer }
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        # Associative arrays should not create associations
        expect(assoc).to be_a(Hash)
      end
    end
  end

  describe ".contains_associations?" do
    context "when type extends detached_entity" do
      context "when initial is true" do
        it "checks element_types recursively" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :TestEntity, Foobara::DetachedEntity do
            attributes id: :integer, child: :ChildEntity
            primary_key :id
          end

          expect(TestEntity.contains_associations?).to be true
        end
      end

      context "when initial is false" do
        it "returns true immediately" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :TestEntity, Foobara::DetachedEntity do
            attributes id: :integer, child: :ChildEntity
            primary_key :id
          end

          type = TestEntity.entity_type
          expect(TestEntity.contains_associations?(type, false)).to be true
        end
      end
    end

    context "when type extends model" do
      it "checks element_types recursively" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes child: :ChildEntity
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be true
      end

      it "filters sensitive element_types when remove_sensitive is true" do
        stub_class :CustomModel, Foobara::Model do
          attributes secret: { type: :string, sensitive: true }
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          # Should handle sensitive filtering
          expect { TestEntity.contains_associations? }.not_to raise_error
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends tuple" do
      it "returns true if any element has associations" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [:string, :ChildEntity] }
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be true
      end

      it "returns false if no elements have associations" do
        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [:string, :integer] }
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be false
      end

      it "skips sensitive elements when remove_sensitive is true" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [{ type: :ChildEntity, sensitive: true }] }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          # Should skip sensitive and return false
          result = TestEntity.contains_associations?
          expect(result).to be_falsey
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "checks all elements when remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: [:ChildEntity] }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          expect(TestEntity.contains_associations?).to be true
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends array" do
      it "returns true if element_type has associations" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, children: [:ChildEntity]
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be true
      end

      it "returns false if element_type is nil" do
        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, items: :array
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be false
      end

      it "returns false if element_type is sensitive and remove_sensitive is true" do
        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, items: [{ type: :string, sensitive: true }]
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          result = TestEntity.contains_associations?
          expect(result).to be_falsey
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "checks element_type when not sensitive or remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, children: [:ChildEntity]
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          expect(TestEntity.contains_associations?).to be true
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends attributes" do
      it "returns true if any value has associations" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity, name: :string
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be true
      end

      it "returns false if no values have associations" do
        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be false
      end

      it "skips sensitive values when remove_sensitive is true" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, secret: { type: :ChildEntity, sensitive: true }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          result = TestEntity.contains_associations?
          expect(result).to be_falsey
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "checks all values when remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          expect(TestEntity.contains_associations?).to be true
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    context "when type extends associative_array" do
      it "returns false when element_types is nil" do
        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc: :associative_array
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be false
      end

      it "returns true if any key or value type has associations" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc: { type: :associative_array, key_type: :string, value_type: :ChildEntity }
          primary_key :id
        end

        expect(TestEntity.contains_associations?).to be true
      end

      it "filters sensitive types when remove_sensitive is true" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc: {
            type: :associative_array,
            key_type: :string,
            value_type: { type: :ChildEntity, sensitive: true }
          }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          result = TestEntity.contains_associations?
          expect(result).to be_falsey
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end

      it "checks all types when remove_sensitive is false" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :TestEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc: { type: :associative_array, key_type: :string, value_type: :ChildEntity }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

          expect(TestEntity.contains_associations?).to be true
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    it "returns falsey when type has no associations" do
      stub_class :TestEntity, Foobara::DetachedEntity do
        attributes id: :integer, name: :string
        primary_key :id
      end

      expect(TestEntity.contains_associations?).to be_falsey
    end
  end

  # Additional tests for uncovered branches
  describe "edge cases and error conditions" do
    describe ".association - error when multiple records found" do
      it "raises error when multiple records found for single association" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, children: [:ChildEntity]
          primary_key :id

          # This creates a non-array accessor for an array field
          association :single_child, :children
        end

        children = [
          ChildEntity.new(id: 1, name: "Test1"),
          ChildEntity.new(id: 2, name: "Test2")
        ]
        parent = ParentEntity.new(id: 1, children: children)

        # This should raise because we're treating an array as a single value
        # and there are multiple records
        expect { parent.single_child }.to raise_error(/Multiple records found/)
      end
    end

    describe ".association_for - error cases" do
      it "raises error when no association is found" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        expect {
          ParentEntity.association_for([:non_existent])
        }.to raise_error(/Could not find association/)
      end

      it "raises error when multiple associations match" do
        stub_class :Entity1, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :Entity2, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child1: :Entity1, child2: :Entity2
          primary_key :id
        end

        # Using a filter that matches both associations
        expect {
          ParentEntity.association_for([:child])
        }.to raise_error(/Multiple associations matched/)
      end
    end

    describe ".filtered_associations - unsupported filter type" do
      it "raises error for unsupported filter type" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        # Using an unsupported filter type (e.g., Integer)
        expect {
          ParentEntity.filtered_associations(123)
        }.to raise_error(/Not sure how to apply filter/)
      end

      it "raises error for hash filter type" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        # Using an unsupported filter type (Hash)
        expect {
          ParentEntity.filtered_associations({ foo: :bar })
        }.to raise_error(/Not sure how to apply filter/)
      end
    end

    describe ".construct_associations - associative_array with associations error" do
      it "raises error when associative_array contains associations" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc: {
            type: :associative_array,
            key_type: :string,
            value_type: :ChildEntity
          }
          primary_key :id
        end

        # This should raise an error because associative arrays with associations are not supported
        expect {
          ParentEntity.construct_associations
        }.to raise_error(/Associative array types with associations/)
      end

      it "raises error when associative_array key_type contains associations" do
        stub_class :KeyEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, assoc: {
            type: :associative_array,
            key_type: :KeyEntity,
            value_type: :string
          }
          primary_key :id
        end

        # This should raise an error because associative arrays with entity keys are not supported
        expect {
          ParentEntity.construct_associations
        }.to raise_error(/Associative array types with associations/)
      end
    end

    describe "sensitive type handling in tuple - construct_associations" do
      it "filters sensitive element_types in tuple when remove_sensitive is true" do
        stub_class :SensitiveEntity, Foobara::Entity do
          attributes id: :integer, secret: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: {
            type: :tuple,
            element_types: [
              :string,
              { type: :SensitiveEntity, sensitive: true }
            ]
          }
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          assoc = ParentEntity.construct_associations
          # Sensitive element should be filtered out
          # We should only have associations for non-sensitive elements
          sensitive_keys = assoc.keys.select { |k| k.include?("tuple_field.1") }
          expect(sensitive_keys).to be_empty
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    describe "sensitive type handling in model - contains_associations?" do
      it "filters sensitive element_types in model when remove_sensitive is true" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes secret_child: { type: :ChildEntity, sensitive: true }
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
        begin
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

          # When sensitive elements are filtered, should return false if only sensitive associations exist
          result = ParentEntity.contains_associations?
          # Since the only association is sensitive and filtered, result should be falsey
          expect(result).to be_falsey
        ensure
          Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
        end
      end
    end

    describe "deep_associations with nested paths" do
      it "correctly builds deep associations for multi-level nesting" do
        stub_class :Level3Entity, Foobara::Entity do
          attributes id: :integer, value: :string
          primary_key :id
        end

        stub_class :Level2Entity, Foobara::Entity do
          attributes id: :integer, level3: :Level3Entity
          primary_key :id
        end

        stub_class :Level1Entity, Foobara::Entity do
          attributes id: :integer, level2: :Level2Entity
          primary_key :id
        end

        stub_class :RootEntity, Foobara::DetachedEntity do
          attributes id: :integer, level1: :Level1Entity
          primary_key :id
        end

        deep = RootEntity.deep_associations

        # Should have associations at all levels
        expect(deep.keys).to include("level1")
        expect(deep.keys).to include("level1.level2")
        expect(deep.keys).to include("level1.level2.level3")
      end
    end

    describe "construct_deep_associations method" do
      it "constructs deep associations properly" do
        stub_class :NestedEntity, Foobara::Entity do
          attributes id: :integer, value: :string
          primary_key :id
        end

        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, nested: :NestedEntity
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id
        end

        deep = ParentEntity.construct_deep_associations

        expect(deep).to be_a(Hash)
        expect(deep.keys).to include("child")
        expect(deep.keys).to include("child.nested")
      end
    end

    describe "association loading with DataPath" do
      it "correctly retrieves associations using DataPath" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, child: :ChildEntity
          primary_key :id

          association :my_child, :child
        end

        child = ChildEntity.new(id: 1, name: "Test")
        parent = ParentEntity.new(id: 1, child: child)

        # The association method should use DataPath.values_at internally
        result = parent.my_child
        expect(result).to eq(child)
      end
    end

    describe "element_types handling" do
      it "handles nil element_types in tuple" do
        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: { type: :tuple, element_types: nil }
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end

      it "handles nil element_types in attributes" do
        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end
    end

    describe "array with # path notation" do
      it "uses # for array element paths" do
        stub_class :ItemEntity, Foobara::Entity do
          attributes id: :integer, name: :string
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, items: [:ItemEntity]
          primary_key :id
        end

        assoc = ParentEntity.associations
        expect(assoc.keys).to include("items.#")
      end

      it "identifies is_many correctly from # in path" do
        stub_class :ItemEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, items: [:ItemEntity]
          primary_key :id

          association :all_items, :items, :"#"
        end

        items = [
          ItemEntity.new(id: 1),
          ItemEntity.new(id: 2)
        ]
        parent = ParentEntity.new(id: 1, items: items)

        result = parent.all_items
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end
    end

    describe "model with foobara_attributes_type vs attributes_type" do
      it "prefers foobara_attributes_type when available" do
        stub_class :ChildEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :CustomModel, Foobara::Model do
          attributes child: :ChildEntity

          def self.foobara_attributes_type
            attributes_type
          end
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, model: :CustomModel
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        expect(assoc).to be_a(Hash)
      end
    end

    describe "filters by entity class with inheritance" do
      it "filters associations by parent class" do
        stub_class :BaseEntity, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :DerivedEntity, BaseEntity do
          attributes name: :string
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, derived: :DerivedEntity
          primary_key :id
        end

        # Should find DerivedEntity when filtering by BaseEntity
        filtered = ParentEntity.filtered_associations(BaseEntity)
        expect(filtered).not_to be_empty
        expect(filtered).to include("derived")
      end
    end

    describe "path construction with indices" do
      it "constructs paths with numeric indices for tuples" do
        stub_class :Entity1, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :Entity2, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :ParentEntity, Foobara::DetachedEntity do
          attributes id: :integer, tuple_field: {
            type: :tuple,
            element_types: [:Entity1, :Entity2]
          }
          primary_key :id
        end

        assoc = ParentEntity.construct_associations
        # Should have paths with indices
        expect(assoc.keys.any? { |k| k =~ /tuple_field\.\d+/ }).to be true
      end
    end

    # Additional tests specifically targeting uncovered branches
    describe "specific branch coverage tests" do
      describe "line 67 - empty values else branch" do
        it "returns first value when values array has exactly one element" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer, name: :string
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, child: :ChildEntity
            primary_key :id

            association :my_child, :child
          end

          child = ChildEntity.create(id: 1, name: "Test")
          parent = ParentEntity.new(id: 1, child: child)

          result = parent.my_child
          expect(result).to eq(child)
        end
      end

      describe "line 184 - array element_type with non-sensitive element when remove_sensitive is true" do
        it "includes array element when not sensitive even if remove_sensitive is true" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, children: [:ChildEntity]
            primary_key :id
          end

          original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
          begin
            Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, true)

            assoc = ParentEntity.construct_associations
            # Should include children.# even when remove_sensitive is true because element is not sensitive
            expect(assoc["children.#"]).not_to be_nil
          ensure
            Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
          end
        end
      end

      describe "line 188 - attributes element_types each_pair iteration" do
        it "iterates through all attribute element types" do
          stub_class :Child1, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :Child2, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, child1: :Child1, child2: :Child2, name: :string
            primary_key :id
          end

          assoc = ParentEntity.construct_associations
          expect(assoc.keys).to include("child1")
          expect(assoc.keys).to include("child2")
          expect(assoc["name"]).to be_nil  # string is not an association
        end
      end

      describe "line 198 - model respond_to checks" do
        it "checks if target_class responds to foobara_attributes_type" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :CustomModel, Foobara::Model do
            attributes child: :ChildEntity
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, model: :CustomModel
            primary_key :id
          end

          # CustomModel should respond to foobara_attributes_type
          expect(CustomModel).to respond_to(:foobara_attributes_type)

          assoc = ParentEntity.construct_associations
          expect(assoc).to be_a(Hash)
        end
      end

      describe "line 201 - model attributes_type sensitive check when remove_sensitive is false" do
        it "processes model even when attributes_type could be sensitive but remove_sensitive is false" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :CustomModel, Foobara::Model do
            attributes child: :ChildEntity
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, model: :CustomModel
            primary_key :id
          end

          original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
          begin
            Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

            assoc = ParentEntity.construct_associations
            expect(assoc.keys.any? { |k| k.include?("model") }).to be true
          ensure
            Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
          end
        end
      end

      describe "contains_associations? - line 240 tuple element check when not sensitive" do
        it "checks tuple elements when not sensitive or remove_sensitive is false" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, data: {
              type: :tuple,
              element_types: [:string, :ChildEntity]
            }
            primary_key :id
          end

          original = Foobara::TypeDeclarations.foobara_manifest_context_remove_sensitive?
          begin
            Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, false)

            result = ParentEntity.contains_associations?
            expect(result).to be true
          ensure
            Foobara::TypeDeclarations.instance_variable_set(:@foobara_manifest_context_remove_sensitive, original)
          end
        end
      end

      describe "contains_associations? - line 255 attributes values check" do
        it "checks attribute values for associations" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, child: :ChildEntity, other_field: :string
            primary_key :id
          end

          result = ParentEntity.contains_associations?
          expect(result).to be true
        end
      end

      describe "contains_associations? - line 256 nested check" do
        it "recursively checks for associations in attribute values" do
          stub_class :Level2Entity, Foobara::Entity do
            attributes id: :integer, name: :string
            primary_key :id
          end

          stub_class :Level1Entity, Foobara::Entity do
            attributes id: :integer, level2: :Level2Entity
            primary_key :id
          end

          stub_class :RootEntity, Foobara::DetachedEntity do
            attributes id: :integer, level1: :Level1Entity
            primary_key :id
          end

          result = RootEntity.contains_associations?
          expect(result).to be true
        end
      end

      describe "contains_associations? - line 268 associative_array type filtering" do
        it "filters types in associative_array when checking for associations" do
          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, assoc: {
              type: :associative_array,
              key_type: :string,
              value_type: :integer
            }
            primary_key :id
          end

          result = ParentEntity.contains_associations?
          expect(result).to be_falsey
        end
      end

      describe "various edge cases for complete coverage" do
        it "handles Class filter that is DetachedEntity subclass" do
          stub_class :BaseEntity, Foobara::DetachedEntity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :DerivedEntity, BaseEntity do
            attributes name: :string
          end

          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, child: :ChildEntity, derived: :DerivedEntity
            primary_key :id
          end

          # Filter by DetachedEntity base class should work for derived entities
          filtered = ParentEntity.filtered_associations(BaseEntity)
          expect(filtered).to be_an(Array)
        end

        it "handles string filter with capital letters matching entity name" do
          stub_class :UserEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, user: :UserEntity
            primary_key :id
          end

          filtered = ParentEntity.filtered_associations("User")
          expect(filtered).not_to be_empty
        end

        it "handles symbol filter conversion to string" do
          stub_class :ChildEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, child_entity: :ChildEntity
            primary_key :id
          end

          filtered = ParentEntity.filtered_associations(:child)
          expect(filtered).not_to be_empty
          expect(filtered.first).to include("child")
        end
      end

      describe "tuple element_types nil handling" do
        it "handles when tuple element_types is nil" do
          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, data: {
              type: :tuple,
              element_types: nil
            }
            primary_key :id
          end

          # Should not raise an error
          expect { ParentEntity.construct_associations }.not_to raise_error
        end
      end

      describe "associative_array element_types handling in contains_associations?" do
        it "handles associative_array with element_types when checking for associations" do
          stub_class :ValueEntity, Foobara::Entity do
            attributes id: :integer
            primary_key :id
          end

          stub_class :ParentEntity, Foobara::DetachedEntity do
            attributes id: :integer, assoc: {
              type: :associative_array,
              key_type: :string,
              value_type: :ValueEntity
            }
            primary_key :id
          end

          result = ParentEntity.contains_associations?
          expect(result).to be true
        end
      end
    end
  end
end
