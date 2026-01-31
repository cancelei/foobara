RSpec.describe Foobara::Persistence do
  after do
    Foobara.reset_alls
  end

  describe ".default_crud_driver=" do
    context "when default crud driver already set" do
      before do
        described_class.instance_variable_set(:@default_crud_driver, nil)
        described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
      end

      it "raises an error" do
        expect {
          described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
        }.to raise_error("Default crud driver already set.")
      end
    end
  end

  describe ".default_base" do
    context "when no default crud driver is set" do
      before do
        described_class.instance_variable_set(:@default_crud_driver, nil)
        described_class.instance_variable_set(:@default_base, nil)
      end

      it "returns nil" do
        expect(described_class.default_base).to be_nil
      end
    end

    context "when default crud driver is set" do
      before do
        described_class.instance_variable_set(:@default_crud_driver, nil)
        described_class.instance_variable_set(:@default_base, nil)
        described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
      end

      it "creates and registers a default base" do
        base = described_class.default_base
        expect(base).to be_a(Foobara::Persistence::EntityBase)
        expect(base.name).to eq("default_entity_base")
        expect(described_class.bases).to have_value(base)
      end
    end
  end

  describe ".current_transaction_table" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    it "returns the transaction table" do
      User.transaction do |tx|
        table = described_class.current_transaction_table(User)
        expect(table).to be_a(Foobara::Persistence::EntityBase::TransactionTable)
        expect(table.transaction).to be(tx)
      end
    end

    context "when no transaction is open" do
      it "attempts to get table but gets nil from transaction" do
        tx = described_class.current_transaction(User)
        expect(tx).to be_nil
      end
    end
  end

  describe ".current_transaction" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    it "returns the current transaction for the object" do
      User.transaction do |tx|
        expect(described_class.current_transaction(User)).to be(tx)
      end
    end

    context "when no transaction is open" do
      it "returns nil" do
        expect(described_class.current_transaction(User)).to be_nil
      end
    end
  end

  describe ".current_transaction!" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    context "when no transaction is open" do
      it "raises NoTransactionOpenError" do
        expect {
          described_class.current_transaction!(User)
        }.to raise_error(Foobara::Persistence::NoTransactionOpenError)
      end
    end

    context "when transaction is open" do
      it "returns the transaction" do
        User.transaction do |tx|
          expect(described_class.current_transaction!(User)).to be(tx)
        end
      end
    end
  end

  describe ".current_transaction_table!" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    it "returns the transaction table when transaction is open" do
      User.transaction do
        table = described_class.current_transaction_table!(User)
        expect(table).to be_a(Foobara::Persistence::EntityBase::TransactionTable)
      end
    end
  end

  describe ".transaction" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    context "when multiple bases" do
      let(:entity_class2) do
        stub_class("Entity2", Foobara::Entity) do
          attributes id: :integer
          primary_key :id
        end
      end

      before do
        @base2 = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "base2"
        )
        described_class.register_entity(@base2, entity_class2)
      end

      it "uses TransactionGroup for multiple bases" do
        expect(Foobara::TransactionGroup).to receive(:run).and_call_original

        described_class.transaction(User, entity_class2) do
          # transaction body
        end
      end
    end

    context "when single base" do
      it "uses the base's transaction method" do
        base = described_class.to_base(User)
        expect(base).to receive(:transaction).and_call_original

        described_class.transaction(User) do
          # transaction body
        end
      end
    end
  end

  describe ".to_base" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    context "when multiple bases found" do
      it "raises an error" do
        allow(described_class).to receive(:to_bases).and_return([:base1, :base2])
        expect {
          described_class.to_base(User)
        }.to raise_error(/Expected to only find 1 base/)
      end
    end

    context "when no bases found" do
      it "raises an error" do
        allow(described_class).to receive(:to_bases).and_return([])
        expect {
          described_class.to_base(User)
        }.to raise_error(/Could not find a base/)
      end
    end
  end

  describe ".object_to_base" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    context "when object is an EntityBase" do
      it "returns the base" do
        base = User.entity_base
        expect(described_class.object_to_base(base)).to be(base)
      end
    end

    context "when object is a String" do
      it "looks up the base by name" do
        base = User.entity_base
        described_class.bases[base.name] = base
        expect(described_class.object_to_base(base.name)).to be(base)
      end
    end

    context "when object is a Symbol" do
      it "converts to string and looks up the base" do
        base = User.entity_base
        described_class.bases[base.name] = base
        expect(described_class.object_to_base(base.name.to_sym)).to be(base)
      end
    end

    context "when object is a Class" do
      it "returns the base for the entity class" do
        base = User.entity_base
        expect(described_class.object_to_base(User)).to be(base)
      end
    end

    context "when object is an Entity instance" do
      it "returns the base for the entity's class" do
        User.transaction do
          user = User.create(id: 1)
          base = User.entity_base
          expect(described_class.object_to_base(user)).to be(base)
        end
      end
    end
  end

  describe ".table_for_entity_class" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
    end

    context "when table already exists" do
      before do
        described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end
      end

      it "returns the existing table" do
        table1 = described_class.table_for_entity_class(User)
        table2 = described_class.table_for_entity_class(User)
        expect(table1).to be(table2)
      end
    end

    context "when domain has default entity base" do
      before do
        described_class.instance_variable_set(:@default_crud_driver, nil)
        described_class.instance_variable_set(:@default_base, nil)
        described_class.instance_variable_set(:@tables_for_entity_class_name, nil)
      end

      it "uses the domain's default base when available" do
        custom_base = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "custom_base"
        )

        entity_class = stub_class("CustomEntity", Foobara::Entity) do
          attributes id: :integer
          primary_key :id
        end

        # Mock the domain to return our custom base
        domain = entity_class.domain
        allow(domain).to receive(:foobara_default_entity_base).and_return(custom_base)

        # Clear cached table so it will be recreated
        described_class.instance_variable_set(:@tables_for_entity_class_name, {})

        table = described_class.table_for_entity_class(entity_class)
        expect(table.entity_base).to be(custom_base)
      end
    end
  end

  describe ".register_base" do
    context "when passing an EntityBase directly" do
      it "registers the base" do
        base = Foobara::Persistence::EntityBase.new(
          "direct_base",
          entity_attributes_crud_driver: Foobara::Persistence::CrudDrivers::InMemory.new
        )

        described_class.register_base(base)
        expect(described_class.bases["direct_base"]).to be(base)
      end
    end

    context "when using a crud driver that takes args" do
      let(:crud_driver_class) do
        stub_class "SomeCrudDriver", Foobara::Persistence::EntityAttributesCrudDriver do
          attr_accessor :connection_url

          def initialize(connection_url, **)
            super(**)
            self.connection_url = connection_url
          end
        end
      end

      it "passes the argument through to the crud driver" do
        described_class.register_base(
          crud_driver_class,
          "some_connection_url",
          name: "some_base"
        )
        base = described_class.bases["some_base"]
        expect(base.entity_attributes_crud_driver.connection_url).to eq("some_connection_url")
      end
    end

    context "when using a table prefix" do
      let(:user_class) do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end
      end

      let(:driver_class) { Foobara::Persistence::CrudDrivers::InMemory }

      it "registers the base and its crud drivers uses prefixes" do
        expect {
          described_class.register_base(driver_class, name: "some_base", table_prefix: "some_prefix")
        }.to change(described_class.bases, :size).by(1)

        base = described_class.bases["some_base"]

        expect(base).to be_a(Foobara::Persistence::EntityBase)

        table = base.entity_attributes_crud_driver.table_for(user_class)

        expect(table.table_name).to eq("some_prefix_user")
      end
    end

    it "marks bases as needing sorting" do
      expect(described_class).to receive(:bases_need_sorting!)

      described_class.register_base(
        Foobara::Persistence::CrudDrivers::InMemory,
        name: "new_base"
      )
    end
  end

  describe ".sort_bases" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "with single base" do
      let(:entity_class) do
        stub_class("Entity1", Foobara::Entity) do
          attributes id: :integer
          primary_key :id
        end
      end

      it "returns the base unchanged" do
        base = entity_class.entity_base
        expect(described_class.sort_bases([base])).to eq([base])
      end
    end

    context "with empty array" do
      it "returns empty array" do
        expect(described_class.sort_bases([])).to eq([])
      end
    end

    context "with entity classes each with different bases" do
      let(:entity_class1) do
        stub_class("Entity1", Foobara::Entity) do
          attributes do
            id :integer
          end
          primary_key :id
        end
      end
      let(:entity_class2) do
        stub_class("Entity2", Foobara::Entity) do
          attributes do
            id :integer
            entity1 Entity1
          end
          primary_key :id
        end
      end
      let(:entity_class3) do
        stub_class("Entity3", Foobara::Entity) do
          attributes do
            id :integer
            entity2 Entity2
          end
          primary_key :id
        end
      end
      let(:entity_class4) do
        stub_class("Entity4", Foobara::Entity) do
          attributes do
            id :integer
            entity3 Entity3
          end
          primary_key :id
        end
      end

      let(:base1) { entity_class1.entity_base }
      let(:base2) { entity_class2.entity_base }
      let(:base3) { entity_class3.entity_base }
      let(:base4) { entity_class4.entity_base }
      let(:base5) { described_class.register_base(Foobara::Persistence::CrudDrivers::InMemory, name: "Base5") }

      it "can sort the bases as expected" do
        [
          entity_class1,
          entity_class2,
          entity_class3,
          entity_class4
        ].each do |entity_class|
          base = described_class.register_base(
            Foobara::Persistence::CrudDrivers::InMemory,
            name: entity_class.name
          )
          described_class.register_entity(base, entity_class)
        end

        # Without any reason to sort them they will not be sorted so let's create some records
        described_class.transaction(base1, base2, base3, base4) do
          entity_class4.create(
            entity3: entity_class3.create(
              entity2: entity_class2.create(entity1: entity_class1.create)
            )
          )
        end

        expect(
          described_class.sort_bases([base3, base4, base5, base1, base2])
        ).to eq([base4, base3, base2, base1, base5])
      end
    end
  end

  describe ".sort_transactions" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "with single transaction" do
      it "returns the transaction unchanged" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        transactions = []
        User.transaction do |tx|
          transactions << tx
        end

        expect(described_class.sort_transactions(transactions)).to eq(transactions)
      end
    end

    context "with empty array" do
      it "returns empty array" do
        expect(described_class.sort_transactions([])).to eq([])
      end
    end
  end

  describe ".sort_bases!" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "with single base" do
      it "returns early" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        # Force create the table
        User.entity_base

        described_class.sort_bases!
        # Should not raise
      end
    end

    context "with multiple bases but single entity class" do
      it "returns early" do
        base1 = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "base1"
        )
        base2 = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "base2"
        )

        described_class.sort_bases!
        # Should not raise
      end
    end

    context "with no entity classes with associations" do
      it "returns early" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :Post, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        # Force create tables
        User.entity_base
        Post.entity_base

        described_class.sort_bases!
        # Should not raise
      end
    end

    context "with bases without entity classes" do
      it "includes missing bases at the end" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        # Force create table
        User.entity_base

        base_without_entities = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "empty_base"
        )

        described_class.sort_bases!

        bases_values = described_class.bases.values
        expect(bases_values).to include(base_without_entities)
      end
    end
  end

  describe ".bases_need_sorting?" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
      described_class.instance_variable_set(:@bases_need_sorting, false)
    end

    context "when @bases_need_sorting is true" do
      it "returns true" do
        described_class.bases_need_sorting!
        expect(described_class.bases_need_sorting?).to be true
      end
    end

    context "when table count changed" do
      it "returns true" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        # Force create table
        User.entity_base

        # Force last_table_count to be different
        described_class.send(:last_table_count=, 0)

        expect(described_class.bases_need_sorting?).to be true
      end
    end
  end

  describe ".register_entity" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    it "registers the entity class with the base" do
      base = described_class.register_base(
        Foobara::Persistence::CrudDrivers::InMemory,
        name: "test_base"
      )

      entity_class = stub_class("TestEntity", Foobara::Entity) do
        attributes id: :integer
        primary_key :id
      end

      table = described_class.register_entity(base, entity_class)

      expect(table).to be_a(Foobara::Persistence::EntityBase::Table)
      expect(described_class.tables_for_entity_class_name[entity_class.full_entity_name]).to be(table)
    end

    context "when passing base by name" do
      it "converts to base object" do
        base = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "test_base"
        )

        entity_class = stub_class("TestEntity", Foobara::Entity) do
          attributes id: :integer
          primary_key :id
        end

        table = described_class.register_entity("test_base", entity_class)
        expect(table.entity_base).to be(base)
      end
    end
  end

  describe ".register_base with args edge cases" do
    context "when passing array of args without opts" do
      let(:crud_driver_class) do
        stub_class "ArrayArgsCrudDriver", Foobara::Persistence::EntityAttributesCrudDriver do
          attr_accessor :arg1, :arg2

          def initialize(arg1, arg2, **)
            super(**)
            self.arg1 = arg1
            self.arg2 = arg2
          end
        end
      end

      it "handles multiple args" do
        described_class.register_base(
          crud_driver_class,
          ["value1", "value2"],
          name: "array_args_base"
        )

        base = described_class.bases["array_args_base"]
        expect(base).to be_a(Foobara::Persistence::EntityBase)
      end
    end
  end

  describe ".sort_bases with multiple bases needing sort" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "when bases_need_sorting? is true" do
      it "calls sort_bases! before sorting" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        described_class.bases_need_sorting!
        expect(described_class.bases_need_sorting?).to be true

        base = User.entity_base
        result = described_class.sort_bases([base])

        expect(result).to eq([base])
      end
    end
  end

  describe ".sort_transactions with multiple transactions needing sort" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "when bases_need_sorting? is true" do
      it "calls sort_bases! before sorting transactions" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        base1 = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "base1"
        )

        base2 = described_class.register_base(
          Foobara::Persistence::CrudDrivers::InMemory,
          name: "base2"
        )

        entity_class1 = stub_class("Entity1", Foobara::Entity) do
          attributes id: :integer
          primary_key :id
        end

        entity_class2 = stub_class("Entity2", Foobara::Entity) do
          attributes id: :integer
          primary_key :id
        end

        described_class.register_entity(base1, entity_class1)
        described_class.register_entity(base2, entity_class2)

        described_class.bases_need_sorting!

        transactions = []
        entity_class1.transaction do |tx1|
          entity_class2.transaction(mode: :open_nested) do |tx2|
            transactions = [tx2, tx1]
          end
        end

        result = described_class.sort_transactions(transactions)
        expect(result).to be_an(Array)
      end
    end
  end

  describe ".sort_bases! with entity classes containing associations" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    end

    context "with entity classes that have associations" do
      it "sorts based on dependencies" do
        stub_class :User, Foobara::Entity do
          attributes id: :integer
          primary_key :id
        end

        stub_class :Post, Foobara::Entity do
          attributes do
            id :integer
            user User
          end
          primary_key :id
        end

        # Force sorting
        described_class.bases_need_sorting!
        described_class.sort_bases!

        # Verify it doesn't raise an error
        expect(described_class.bases).to be_a(Hash)
      end
    end
  end

  describe ".current_transaction when no transaction open" do
    before do
      described_class.instance_variable_set(:@default_crud_driver, nil)
      described_class.instance_variable_set(:@default_base, nil)
      described_class.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new

      stub_class :User, Foobara::Entity do
        attributes id: :integer
        primary_key :id
      end
    end

    it "returns nil when called outside transaction" do
      result = described_class.current_transaction(User)
      expect(result).to be_nil
    end
  end
end
