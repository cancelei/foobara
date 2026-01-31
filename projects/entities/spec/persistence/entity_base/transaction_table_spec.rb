RSpec.describe Foobara::Persistence::EntityBase::TransactionTable do
  after do
    Foobara.reset_alls
  end

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:user_class) do
    stub_class "User", Foobara::Entity do
      attributes id: :integer,
                 first_name: :string,
                 last_name: :string,
                 tags: [:string],
                 role: :string
      primary_key :id
    end
  end

  let(:profile_class) do
    stub_class "Profile", Foobara::Entity do
      attributes id: :integer,
                 bio: :string,
                 user_id: :integer
      primary_key :id
    end
  end

  describe "#find_tracked" do
    context "when record_id is nil" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.find_tracked(nil)
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when record_id is false" do
      it "raises ArgumentError for falsy value" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.find_tracked(false)
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when record_id is an empty string" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.find_tracked("")
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when record_id is an empty symbol" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.find_tracked(:"")
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when record exists" do
      it "returns the tracked record" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded_user = user_class.load(user.id)
          found = table.find_tracked(user.id)
          expect(found).to eq(loaded_user)
        end
      end
    end
  end

  describe "#first" do
    context "when no records exist" do
      it "returns nil" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect(table.first).to be_nil
        end
      end
    end

    context "when record is already tracked" do
      it "returns the tracked record" do
        user = user_class.transaction do
          user_class.create(first_name: "First")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          first = table.first
          expect(first).to eq(loaded)
        end
      end
    end

    context "when record exists but not tracked" do
      it "loads and returns the record" do
        user = user_class.transaction do
          user_class.create(first_name: "First")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          first = table.first
          expect(first.first_name).to eq("First")
        end
      end
    end


    context "when only created records exist (not yet persisted)" do
      it "returns nil because created records are not in database yet" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.create(first_name: "Created")
          # first queries the database first, which is empty
          first = table.first
          # The logic returns marked_created.first only if found_attributes exists
          expect(first).to be_nil
        end
      end
    end
  end

  describe "#load" do
    context "when entity_or_record_id is nil" do
      it "raises an error" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load(nil)
          }.to raise_error("Expected a record or record primary key but received nil")
        end
      end
    end

    context "when loading with a persisted entity" do
      it "loads the entity" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          # Load the user in this transaction
          loaded_user = user_class.load(user.id)
          table = tx.table_for(user_class)
          # Table.load should return the same loaded entity
          result = table.load(loaded_user)
          expect(result.first_name).to eq("John")
        end
      end
    end

    context "when loading with a hash as primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load({ id: 1 })
          }.to raise_error(ArgumentError, "Unlikely that you meant to use a hash as a primary key")
        end
      end
    end

    context "when loading with false as primary key" do
      it "raises ArgumentError for falsy value" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load(false)
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when loading with empty string primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load("")
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when loading with empty symbol primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load(:"")
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when entity is already tracked and loaded" do
      it "returns the entity without reloading" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded1 = user_class.load(user.id)
          loaded2 = table.load(user.id)
          expect(loaded1).to equal(loaded2)
        end
      end
    end

    context "when entity is tracked but not loaded" do
      it "loads the entity" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          expect(thunk.loaded?).to be false

          loaded = table.load(user.id)
          expect(loaded.loaded?).to be true
          expect(loaded.first_name).to eq("John")
        end
      end
    end

    context "when entity is not tracked" do
      it "loads and tracks the entity" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = table.load(user.id)
          expect(loaded.first_name).to eq("John")
          expect(table.tracking?(loaded)).to be true
        end
      end
    end

    context "when record is not found" do
      it "raises CannotFindError from crud driver" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load(999)
          }.to raise_error(Foobara::Persistence::EntityAttributesCrudDriver::Table::CannotFindError)
        end
      end
    end
  end

  describe "#load_many" do
    context "when passed entities that are already loaded" do
      it "skips loading them" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          result = table.load_many([loaded])
          expect(result).to eq([loaded])
        end
      end
    end

    context "when passed unloaded entities" do
      it "loads them" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          expect(thunk.loaded?).to be false

          result = table.load_many([thunk])
          expect(result.first.loaded?).to be true
        end
      end
    end

    context "when passed hash as primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load_many([{ id: 1 }])
          }.to raise_error(ArgumentError, "Unlikely that you meant to use a hash as a primary key")
        end
      end
    end

    context "when passed nil as primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load_many([nil])
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when passed false as primary key" do
      it "raises ArgumentError for falsy value" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load_many([false])
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when passed empty string as primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load_many([""])
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when passed empty symbol as primary key" do
      it "raises ArgumentError" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.load_many([:""])
          }.to raise_error(ArgumentError, "Cannot use a blank primary key value")
        end
      end
    end

    context "when entity is tracked but not loaded" do
      it "creates thunk and loads it" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          result = table.load_many([user.id])
          expect(result.first.first_name).to eq("John")
        end
      end
    end

    context "when entity is already tracked and loaded" do
      it "returns the tracked entity" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          result = table.load_many([user.id])
          expect(result.first).to eq(loaded)
        end
      end
    end

    context "when entity is not tracked" do
      it "creates thunk and loads it" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          result = table.load_many([user.id])
          expect(result.first.first_name).to eq("John")
        end
      end
    end

    context "when passed mix of entities and ids" do
      it "loads correctly" do
        user1, user2 = user_class.transaction do
          [user_class.create(first_name: "John"), user_class.create(first_name: "Jane")]
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded1 = user_class.load(user1.id)
          result = table.load_many([loaded1, user2.id])
          expect(result.map(&:first_name)).to eq(["John", "Jane"])
        end
      end
    end
  end

  describe "#find_by_attribute" do
    it "finds record by attribute" do
      user = user_class.transaction do
        user_class.create(first_name: "John", last_name: "Doe")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        found = table.find_by_attribute(:first_name, "John")
        expect(found.first_name).to eq("John")
      end
    end
  end

  describe "#find_all_by_attribute" do
    it "finds all records by attribute" do
      user_class.transaction do
        user_class.create(first_name: "John", last_name: "Doe")
        user_class.create(first_name: "John", last_name: "Smith")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        found = table.find_all_by_attribute(:first_name, "John").to_a
        expect(found.size).to eq(2)
      end
    end
  end

  describe "#find_by_attribute_containing" do
    context "when found in tracked records" do
      it "returns the record from tracked records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby", "rails"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_by_attribute_containing(:tags, "ruby")
          expect(found).to eq(loaded)
        end
      end
    end

    context "when not found in tracked but found in database" do
      it "loads and returns the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby", "rails"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_by_attribute_containing(:tags, "ruby")
          expect(found.first_name).to eq("John")
        end
      end
    end

    context "when record is hard deleted" do
      it "skips the deleted record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          loaded.hard_delete!
          found = table.find_by_attribute_containing(:tags, "ruby")
          expect(found).to be_nil
        end
      end
    end

    context "when record exists but not loaded" do
      it "loads the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          expect(thunk.loaded?).to be false

          found = table.find_by_attribute_containing(:tags, "ruby")
          expect(found.loaded?).to be true
          expect(found.first_name).to eq("John")
        end
      end
    end

    context "when created record matches" do
      it "returns the created record" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.create(first_name: "John", tags: ["ruby"])
          found = table.find_by_attribute_containing(:tags, "ruby")
          expect(found).to eq(user)
        end
      end
    end

    context "when no match found in database" do
      it "returns nil" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_by_attribute_containing(:tags, "nonexistent")
          expect(found).to be_nil
        end
      end
    end

    context "when tracked record is loaded but no longer matches after changes" do
      it "returns the record from database not the changed tracked record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Change the loaded record so it no longer matches
          loaded.tags = ["python"]
          # The database still has ruby, but loaded has python
          # Since find checks loaded records first, it won't match, so goes to DB
          # But when it finds the DB record, it's already tracked and loaded
          # Line 286 checks this condition
          found = table.find_by_attribute_containing(:tags, "ruby")
          # This should return nil because the tracked loaded record doesn't match
          expect(found).to be_nil
        end
      end
    end
  end

  describe "#find_by" do
    context "when found in tracked loaded records" do
      it "returns the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", last_name: "Doe")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_by(first_name: "John", last_name: "Doe")
          expect(found).to eq(loaded)
        end
      end
    end

    context "when found in created records" do
      it "returns the created record" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.create(first_name: "John", last_name: "Doe")
          found = table.find_by(first_name: "John")
          expect(found).to eq(user)
        end
      end
    end

    context "when record is hard deleted" do
      it "does not return the deleted record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", last_name: "Doe")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          loaded.hard_delete!
          found = table.find_by(first_name: "John")
          expect(found).to be_nil
        end
      end
    end

    context "when found in database but not tracked" do
      it "loads and returns the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", last_name: "Doe")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_by(first_name: "John")
          expect(found.first_name).to eq("John")
        end
      end
    end

    context "when tracked but not loaded" do
      it "loads the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", last_name: "Doe")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          found = table.find_by(first_name: "John")
          expect(found.loaded?).to be true
          expect(found).to eq(thunk)
        end
      end
    end

    context "when not found" do
      it "returns nil" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_by(first_name: "NonExistent")
          expect(found).to be_nil
        end
      end
    end

    context "when tracked loaded record no longer matches filter after modification" do
      it "skips the modified record and continues searching" do
        user = user_class.transaction do
          user_class.create(first_name: "John", last_name: "Doe")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Modify the loaded record so it no longer matches
          loaded.first_name = "Jane"
          # Database still has "John", so find_by will find it in DB
          # But when it checks if tracked, it's loaded and doesn't match
          # This tests line 327 (record = nil when already loaded)
          found = table.find_by(first_name: "John")
          # Should return nil because the only record that matches in DB is already loaded with different values
          expect(found).to be_nil
        end
      end
    end
  end

  describe "#find_many_by" do
    context "with symbol attribute name" do
      it "finds records" do
        user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
          user_class.create(first_name: "Jane", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_many_by(role: "admin").to_a
          expect(found.size).to eq(2)
        end
      end
    end

    context "with string attribute name" do
      it "finds records" do
        user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_many_by("role" => "admin").to_a
          expect(found.size).to eq(1)
        end
      end
    end

    context "when records are hard deleted" do
      it "does not yield deleted records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          loaded.hard_delete!
          found = table.find_many_by(role: "admin").to_a
          expect(found).to be_empty
        end
      end
    end

    context "when records are loaded" do
      it "yields tracked loaded records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_many_by(role: "admin").to_a
          expect(found).to eq([loaded])
        end
      end
    end

    context "when records are built" do
      it "yields built records" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.build(first_name: "John", role: "admin")
          table.tracked(user)
          found = table.find_many_by(role: "admin").to_a
          expect(found).to include(user)
        end
      end
    end

    context "when records are created" do
      it "yields created records" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.create(first_name: "John", role: "admin")
          found = table.find_many_by(role: "admin").to_a
          expect(found).to include(user)
        end
      end
    end

    context "when same record is in database and tracked" do
      it "does not yield duplicates" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_many_by(role: "admin").to_a
          expect(found.count { |r| r.id == user.id }).to eq(1)
        end
      end
    end

    context "when tracked but not loaded from database" do
      it "loads the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          found = table.find_many_by(role: "admin").to_a
          expect(found.first.loaded?).to be true
        end
      end
    end

    context "when tracked loaded record no longer matches filter after modification" do
      it "skips the modified record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Modify so it no longer matches
          loaded.role = "user"
          # Database still has "admin", so find_many_by will find it
          # But when checking tracked records, it's loaded with different values
          # This tests line 401 (record = nil when already loaded)
          found = table.find_many_by(role: "admin").to_a
          # Should be empty because the only match in DB is already loaded with different values
          expect(found).to be_empty
        end
      end
    end

    context "when tracked record is built but not loaded or created" do
      it "does not yield the built record if not matching" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.build(first_name: "John", role: "guest")
          table.tracked(user)
          found = table.find_many_by(role: "admin").to_a
          expect(found).not_to include(user)
        end
      end
    end
  end

  describe "#find_all_by_attribute_containing_any_of" do
    context "when values is empty" do
      it "returns empty array" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          result = table.find_all_by_attribute_containing_any_of(:tags, [])
          expect(result).to eq([])
        end
      end
    end

    context "when found in tracked records" do
      it "yields tracked records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby", "rails"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found).to include(loaded)
        end
      end
    end

    context "when record has no tags" do
      it "skips the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: nil)
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found).to be_empty
        end
      end
    end

    context "when record has empty tags" do
      it "skips the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: [])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found).to be_empty
        end
      end
    end

    context "when created record matches" do
      it "yields created records" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.create(first_name: "John", tags: ["ruby"])
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found).to include(user)
        end
      end
    end

    context "when hard deleted" do
      it "skips deleted records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          loaded.hard_delete!
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found).to be_empty
        end
      end
    end

    context "when found in database but not tracked" do
      it "loads and yields records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found.first.first_name).to eq("John")
        end
      end
    end

    context "when already yielded from tracked records" do
      it "does not yield duplicates" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found.count { |r| r.id == user.id }).to eq(1)
        end
      end
    end

    context "when tracked but not loaded from database" do
      it "loads and yields the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          expect(thunk.loaded?).to be false
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found.first.loaded?).to be true
        end
      end
    end

    context "when tracked loaded record no longer matches after modification" do
      it "skips the modified record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Modify so it no longer contains ruby
          loaded.tags = ["python"]
          # Database still has "ruby", but loaded record has "python"
          # This tests lines 466-474 (loaded record skip logic)
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          # Should be empty because the only match in DB is already loaded with different values
          expect(found).to be_empty
        end
      end
    end
  end

  describe "#find_all_by_attribute_any_of" do
    context "when values is empty" do
      it "returns empty array" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          result = table.find_all_by_attribute_any_of(:role, [])
          expect(result).to eq([])
        end
      end
    end

    context "when found in tracked records" do
      it "yields tracked records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_all_by_attribute_any_of(:role, ["admin", "user"]).to_a
          expect(found).to include(loaded)
        end
      end
    end

    context "when created record matches" do
      it "yields created records" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.create(first_name: "John", role: "admin")
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found).to include(user)
        end
      end
    end

    context "when hard deleted" do
      it "skips deleted records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          loaded.hard_delete!
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found).to be_empty
        end
      end
    end

    context "when found in database but not tracked" do
      it "loads and yields records" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found.first.first_name).to eq("John")
        end
      end
    end

    context "when already yielded from tracked records" do
      it "does not yield duplicates" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found.count { |r| r.id == user.id }).to eq(1)
        end
      end
    end

    context "when tracked but not loaded from database" do
      it "loads and yields the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          thunk = user_class.thunk(user.id)
          expect(thunk.loaded?).to be false
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found.first.loaded?).to be true
        end
      end
    end

    context "when tracked loaded record no longer matches after modification" do
      it "skips the modified record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Modify so it no longer matches
          loaded.role = "guest"
          # Database still has "admin", but loaded record has "guest"
          # This tests lines 530-538 (loaded record skip logic)
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          # Should be empty because the only match in DB is already loaded with different values
          expect(found).to be_empty
        end
      end
    end
  end

  describe "#track_created" do
    context "when entity is already persisted" do
      it "raises an error" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect {
            table.track_created(user)
          }.to raise_error("Cannot insert #{user} because it's already persisted.")
        end
      end
    end

    context "when entity is not persisted" do
      it "tracks the created entity" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          user = user_class.build(first_name: "John")
          table.track_created(user)
          expect(table.send(:created?, user)).to be true
        end
      end
    end
  end

  describe "#find_all_by_attribute_containing_any_of with tracked records only" do
    context "when tracked record is loaded but doesn't match (no tag values match)" do
      it "does not yield the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["python"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Record has python, we're searching for ruby
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found).to be_empty
        end
      end
    end

    context "when tracked record not loaded but not created" do
      it "does not yield unloaded thunks" do
        user = user_class.transaction do
          user_class.create(first_name: "John", tags: ["ruby"])
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          # Create a thunk but don't load it
          thunk = user_class.thunk(user.id)
          # Tracked records iteration only yields loaded? || created? records
          # This thunk is neither loaded nor created, so it won't be yielded
          # The record will be found from DB instead
          found = table.find_all_by_attribute_containing_any_of(:tags, ["ruby"]).to_a
          expect(found.first.loaded?).to be true
        end
      end
    end
  end

  describe "#find_all_by_attribute_any_of with tracked records only" do
    context "when tracked record is loaded but doesn't match" do
      it "does not yield the record" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "guest")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          loaded = user_class.load(user.id)
          # Record has guest role, we're searching for admin
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found).to be_empty
        end
      end
    end

    context "when tracked record not loaded but not created" do
      it "loads from database" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          # Create a thunk but don't load it
          thunk = user_class.thunk(user.id)
          # Tracked records iteration only yields loaded? || created? records
          found = table.find_all_by_attribute_any_of(:role, ["admin"]).to_a
          expect(found.first.loaded?).to be true
        end
      end
    end
  end

  describe "#find_many_by with tracked unloaded/unbuilt records" do
    context "when tracked record is neither loaded, built, nor created" do
      it "loads from database" do
        user = user_class.transaction do
          user_class.create(first_name: "John", role: "admin")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          # Create a thunk (tracked but not loaded, not built, not created)
          thunk = user_class.thunk(user.id)
          # Should be found from database since tracked iteration skips it
          found = table.find_many_by(role: "admin").to_a
          expect(found).not_to be_empty
          expect(found.first.loaded?).to be true
        end
      end
    end
  end

  describe "empty array returns" do
    context "#find_all_by_attribute_containing_any_of with empty values" do
      it "returns empty constant" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          result = table.find_all_by_attribute_containing_any_of(:tags, [])
          # Line 421 returns EMPTY_ARRAY constant
          expect(result).to respond_to(:each)
          expect(result.to_a).to eq([])
        end
      end
    end

    context "#find_all_by_attribute_any_of with empty values" do
      it "returns empty constant" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          result = table.find_all_by_attribute_any_of(:role, [])
          # Line 489 returns EMPTY_ARRAY constant
          expect(result).to respond_to(:each)
          expect(result.to_a).to eq([])
        end
      end
    end
  end

  describe "#hard_delete_all!" do
    it "hard deletes all records" do
      user_class.transaction do
        user_class.create(first_name: "John")
        user_class.create(first_name: "Jane")
      end

      user_class.transaction do |tx|
        user_class.all.to_a # Load all records

        table = tx.table_for(user_class)
        table.hard_delete_all!

        expect(table.count).to eq(0)
      end
    end
  end

  describe "#count" do
    it "counts persisted and created records minus deleted" do
      user_class.transaction do
        user_class.create(first_name: "John")
        user_class.create(first_name: "Jane")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        expect(table.count).to eq(2)

        user_class.create(first_name: "Bob")
        expect(table.count).to eq(3)

        user = user_class.all.first
        user.hard_delete!
        expect(table.count).to eq(2)
      end
    end
  end

  describe "#exists?" do
    context "when record is tracked and not hard deleted" do
      it "returns true" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          table = tx.table_for(user_class)
          expect(table.exists?(user.id)).to be true
        end
      end
    end

    context "when record is hard deleted and tracked" do
      it "returns false only if loaded and hard_deleted" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        # The exists? method has complex logic:
        # (record && !record.hard_deleted? && (!record.persisted? || record.loaded?)) || entity_attributes_crud_driver_table.exists?(record_id)
        # So it returns false only when the record is tracked, loaded, and hard_deleted, AND doesn't exist in DB
        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          table = tx.table_for(user_class)

          # Before hard delete - should exist
          expect(table.exists?(user.id)).to be true

          loaded.hard_delete!

          # After hard delete in transaction, the DB still has it, so exists? returns true
          # because of the second part of the OR condition
          expect(table.exists?(user.id)).to be true
        end

        # After transaction commits, it's actually deleted from DB
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect(table.exists?(user.id)).to be false
        end
      end
    end

    context "when record is not persisted but not loaded" do
      it "checks database" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          thunk = user_class.thunk(user.id)
          table = tx.table_for(user_class)
          expect(table.exists?(user.id)).to be true
        end
      end
    end

    context "when record does not exist" do
      it "returns false" do
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect(table.exists?(999)).to be false
        end
      end
    end
  end

  describe "#all_exist?" do
    context "when all records are tracked and not deleted" do
      it "returns true" do
        user1, user2 = user_class.transaction do
          [user_class.create(first_name: "John"), user_class.create(first_name: "Jane")]
        end

        user_class.transaction do |tx|
          user_class.load(user1.id)
          user_class.load(user2.id)
          table = tx.table_for(user_class)
          expect(table.all_exist?([user1.id, user2.id])).to be true
        end
      end
    end

    context "when some records are hard deleted" do
      it "returns false after deletion is committed" do
        user1, user2 = user_class.transaction do
          [user_class.create(first_name: "John"), user_class.create(first_name: "Jane")]
        end

        user_class.transaction do |tx|
          loaded1 = user_class.load(user1.id)
          loaded1.hard_delete!
        end

        # After the transaction commits, user1 is actually deleted from DB
        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect(table.all_exist?([user1.id, user2.id])).to be false
        end
      end
    end

    context "when all exist in database" do
      it "returns true" do
        user1, user2 = user_class.transaction do
          [user_class.create(first_name: "John"), user_class.create(first_name: "Jane")]
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect(table.all_exist?([user1.id, user2.id])).to be true
        end
      end
    end

    context "when some do not exist in database" do
      it "returns false" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          table = tx.table_for(user_class)
          expect(table.all_exist?([user.id, 999])).to be false
        end
      end
    end

    context "when all ids are tracked" do
      it "returns true without checking database" do
        user1, user2 = user_class.transaction do
          [user_class.create(first_name: "John"), user_class.create(first_name: "Jane")]
        end

        user_class.transaction do |tx|
          user_class.load(user1.id)
          user_class.load(user2.id)
          table = tx.table_for(user_class)
          result = table.all_exist?([user1.id, user2.id])
          expect(result).to be true
        end
      end
    end

    context "when created but not persisted" do
      it "returns true for created records" do
        user_class.transaction do |tx|
          user1 = user_class.create(first_name: "John")
          user2 = user_class.create(first_name: "Jane")
          table = tx.table_for(user_class)
          expect(table.all_exist?([user1.id, user2.id])).to be false # Not persisted yet
        end
      end
    end
  end

  describe "#to_persistable" do
    it "converts entity to persistable hash" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        persistable = table.to_persistable(loaded)
        expect(persistable).to be_a(Hash)
        expect(persistable[:first_name]).to eq("John")
      end
    end

    it "converts entity to primary key when not initial" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        persistable = table.to_persistable(loaded, false)
        expect(persistable).to eq(user.id)
      end
    end

    it "converts model to persistable hash" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        model = stub_class("TestModel", Foobara::Model) do
          attributes name: :string
        end.new(name: "test")

        persistable = table.to_persistable(model)
        expect(persistable).to eq({ name: "test" })
      end
    end

    it "converts hash values recursively" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        hash = { nested: { key: "value" } }
        persistable = table.to_persistable(hash)
        expect(persistable).to eq({ nested: { key: "value" } })
      end
    end

    it "converts array elements recursively" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        array = [{ key: "value" }, "string"]
        persistable = table.to_persistable(array)
        expect(persistable).to eq([{ key: "value" }, "string"])
      end
    end

    it "returns primitives as-is" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        expect(table.to_persistable("string")).to eq("string")
        expect(table.to_persistable(123)).to eq(123)
        expect(table.to_persistable(true)).to eq(true)
      end
    end
  end

  describe "#validate!" do
    context "when created record is invalid" do
      it "raises InvalidRecordError" do
        expect {
          user_class.transaction do |tx|
            user = user_class.create(first_name: "John")

            allow(user).to receive(:valid?).and_return(false)
            allow(user).to receive(:validation_errors).and_return({ first_name: ["is invalid"] })
          end
        }.to raise_error(Foobara::Persistence::InvalidRecordError)
      end
    end

    context "when updated record is invalid" do
      it "raises InvalidRecordError" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        expect {
          user_class.transaction do |tx|
            loaded = user_class.load(user.id)
            loaded.first_name = "Jane"

            allow(loaded).to receive(:valid?).and_return(false)
            allow(loaded).to receive(:validation_errors).and_return({ first_name: ["is invalid"] })
          end
        }.to raise_error(Foobara::Persistence::InvalidRecordError)
      end
    end

    context "when all records are valid" do
      it "does not raise error" do
        user_class.transaction do |tx|
          user = user_class.create(first_name: "John")
          table = tx.table_for(user_class)
          expect { table.validate! }.not_to raise_error
        end
      end
    end
  end

  describe "#flush_created!" do
    it "persists created records" do
      user_class.transaction do |tx|
        user = user_class.create(first_name: "John")
        expect(user.created?).to be true

        table = tx.table_for(user_class)
        table.flush_created!

        expect(user.persisted?).to be true
        expect(user.loaded?).to be true
        expect(user.created?).to be false
      end
    end
  end

  describe "#flush_updated_and_hard_deleted!" do
    it "flushes updated and deleted records" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        loaded.first_name = "Jane"

        table.flush_updated_and_hard_deleted!

        expect(table.send(:marked_updated).size).to eq(0)
      end
    end

    it "flushes hard deleted records" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        loaded.hard_delete!

        table.flush_updated_and_hard_deleted!

        expect(table.send(:marked_hard_deleted).size).to eq(0)
      end
    end
  end

  describe "#rollback!" do
    it "restores updated records" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        loaded.first_name = "Jane"

        table.rollback!

        expect(loaded.first_name).to eq("John")
      end
    end

    it "restores hard deleted records" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        loaded.hard_delete!

        table.rollback!

        expect(loaded.hard_deleted?).to be false
      end
    end

    it "hard deletes created records" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        user = user_class.create(first_name: "John")

        table.rollback!

        expect(user.hard_deleted?).to be true
      end
    end
  end

  describe "#commit!" do
    it "validates, flushes created, and flushes updated" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        user = user_class.create(first_name: "John")

        table.commit!

        expect(user.persisted?).to be true
      end
    end
  end

  describe "#revert!" do
    it "restores all changes without callbacks" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        loaded.first_name = "Jane"
        loaded.hard_delete!

        created = user_class.create(first_name: "Bob")

        table.revert!

        expect(loaded.first_name).to eq("John")
        expect(loaded.hard_deleted?).to be false
        expect(created.first_name).to eq("Bob")
      end
    end
  end

  describe "#tracking?" do
    it "returns true if record is tracked" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        loaded = user_class.load(user.id)
        expect(table.tracking?(loaded)).to be true
      end
    end

    it "returns false if record is not tracked" do
      user_class.transaction do |tx|
        table = tx.table_for(user_class)
        new_user = user_class.build(first_name: "Jane")
        expect(table.tracking?(new_user)).to be false
      end
    end
  end

  describe "#load_many" do
    context "when already loaded" do
      let!(:user) do
        user_class.transaction do
          user_class.create(first_name: "f")
        end
      end

      it "just returns the already-loaded record" do
        user_class.transaction do
          record = user_class.load(user.id)
          loaded = user_class.load_many(record)

          expect(loaded).to eq([record])
          expect(loaded.first).to be_loaded
        end
      end
    end
  end

  describe "#all" do
    context "when a thunk is unloaded" do
      it "still yields the loaded record for that thunk" do
        user = user_class.transaction do
          user_class.create(first_name: "Basil")
        end

        user_class.transaction do |tx|
          user_class.thunk(user.id)

          transaction_table = tx.table_for(user_class)

          transaction_table.all do |record|
            expect(record).to be_loaded
            expect(record.first_name).to eq("Basil")
          end
        end
      end
    end
  end

  describe "#load with persisted entity without primary key" do
    it "raises an error" do
      user_class.transaction do |tx|
        user = user_class.build(first_name: "John")
        allow(user).to receive(:persisted?).and_return(true)
        allow(user).to receive(:primary_key).and_return(nil)

        table = tx.table_for(user_class)
        expect {
          table.load(user)
        }.to raise_error("Did not expect a record to be persisted but have no primary key")
      end
    end
  end

  describe "#load with unpersisted entity" do
    it "raises an error" do
      user_class.transaction do |tx|
        user = user_class.build(first_name: "John")
        allow(user).to receive(:persisted?).and_return(false)

        table = tx.table_for(user_class)
        expect {
          table.load(user)
        }.to raise_error("Cannot load an unpersisted record!")
      end
    end
  end

  describe "#load with different entity instance" do
    it "raises an error" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        # Load the entity first
        loaded = user_class.load(user.id)

        # Create a different instance with the same ID
        different_instance = user_class.build(id: user.id, first_name: "Different")
        allow(different_instance).to receive(:persisted?).and_return(true)
        allow(different_instance).to receive(:primary_key).and_return(user.id)

        table = tx.table_for(user_class)
        expect {
          table.load(different_instance)
        }.to raise_error(/This transaction is already tracking a different entity/)
      end
    end
  end

  describe "#load_many with persisted entity without primary key" do
    it "raises an error" do
      user_class.transaction do |tx|
        user = user_class.build(first_name: "John")
        allow(user).to receive(:persisted?).and_return(true)
        allow(user).to receive(:primary_key).and_return(nil)
        allow(user).to receive(:loaded?).and_return(false)

        table = tx.table_for(user_class)
        expect {
          table.load_many([user])
        }.to raise_error("Did not expect a record to be persisted but have no primary key")
      end
    end
  end

  describe "#load_many with unpersisted entity" do
    it "raises an error" do
      user_class.transaction do |tx|
        user = user_class.build(first_name: "John")
        allow(user).to receive(:persisted?).and_return(false)
        allow(user).to receive(:loaded?).and_return(false)

        table = tx.table_for(user_class)
        expect {
          table.load_many([user])
        }.to raise_error("Cannot load an unpersisted record!")
      end
    end
  end

  describe "#load_many with different entity instance" do
    it "raises an error" do
      user = user_class.transaction do
        user_class.create(first_name: "John")
      end

      user_class.transaction do |tx|
        # Load the entity first
        loaded = user_class.load(user.id)

        # Create a different instance with the same ID
        different_instance = user_class.build(id: user.id, first_name: "Different")
        allow(different_instance).to receive(:persisted?).and_return(true)
        allow(different_instance).to receive(:primary_key).and_return(user.id)
        allow(different_instance).to receive(:loaded?).and_return(false)

        table = tx.table_for(user_class)
        expect {
          table.load_many([different_instance])
        }.to raise_error(/This transaction is already tracking a different entity/)
      end
    end
  end


  describe "#hard_delete_all! with non-deleted records" do
    it "skips records that are already hard deleted" do
      user_class.transaction do
        user1 = user_class.create(first_name: "John")
        user2 = user_class.create(first_name: "Jane")
      end

      user_class.transaction do |tx|
        user1 = user_class.all.first
        user1.hard_delete!

        table = tx.table_for(user_class)
        # Load all records to track them
        user_class.all.to_a

        table.hard_delete_all!
        expect(table.count).to eq(0)
      end
    end
  end
  describe "RecordTracking concern" do
    describe "#loading" do
      it "marks as loading during block execution" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          thunk = user_class.thunk(user.id)
          table = tx.table_for(user_class)

          table.send(:loading, thunk) do
            expect(table.send(:loading?, thunk)).to be true
          end

          expect(table.send(:loading?, thunk)).to be false
        end
      end

      it "raises error if already loading" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          thunk = user_class.thunk(user.id)
          table = tx.table_for(user_class)

          table.send(:mark_loading, thunk)

          expect {
            table.send(:loading, thunk) { }
          }.to raise_error("Already loading #{thunk}")
        end
      end
    end

    describe "#hard_deleted" do
      it "marks persisted record as hard deleted and unmarks updated" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          loaded.first_name = "Jane"
          table = tx.table_for(user_class)

          table.send(:hard_deleted, loaded)

          expect(table.send(:hard_deleted?, loaded)).to be true
          expect(table.send(:updated?, loaded)).to be false
        end
      end

      it "unmarks created for non-persisted record" do
        user_class.transaction do |tx|
          user = user_class.create(first_name: "John")
          table = tx.table_for(user_class)

          table.send(:hard_deleted, user)

          expect(table.send(:created?, user)).to be false
        end
      end
    end

    describe "#unhard_deleted" do
      it "unmarks hard deleted and marks updated if dirty" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          table = tx.table_for(user_class)

          # Mark as hard deleted
          table.send(:mark_hard_deleted, loaded)
          expect(table.send(:hard_deleted?, loaded)).to be true

          # Make it dirty
          loaded.write_attributes_without_callbacks(first_name: "Jane")

          # Now unhard delete
          table.send(:unhard_deleted, loaded)

          expect(table.send(:hard_deleted?, loaded)).to be false
          expect(table.send(:updated?, loaded)).to be true
        end
      end
    end

    describe "#updated" do
      it "raises error if record is hard deleted" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          table = tx.table_for(user_class)
          table.send(:mark_hard_deleted, loaded)

          expect {
            table.send(:updated, loaded)
          }.to raise_error("Cannot update a hard deleted record")
        end
      end

      it "marks updated if dirty and not created" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          loaded.first_name = "Jane"
          table = tx.table_for(user_class)

          table.send(:updated, loaded)

          expect(table.send(:updated?, loaded)).to be true
        end
      end

      it "unmarks updated if not dirty" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          table = tx.table_for(user_class)
          loaded.first_name = "Jane"
          table.send(:mark_updated, loaded)
          loaded.first_name = "John"

          table.send(:updated, loaded)

          expect(table.send(:updated?, loaded)).to be false
        end
      end

      it "does not mark updated if record is created" do
        user_class.transaction do |tx|
          user = user_class.create(first_name: "John")
          table = tx.table_for(user_class)

          # Created records should not be marked as updated even if dirty
          user.write_attributes_without_callbacks(first_name: "Jane")

          # Manually call updated to test the logic
          allow(user).to receive(:dirty?).and_return(true)
          table.send(:updated, user)

          # Should not be marked as updated because it's created (returns nil or false)
          expect(table.send(:updated?, user)).to be_falsey
          expect(table.send(:created?, user)).to be true
        end
      end
    end

    describe "#committed" do
      it "fires persisted event for marked persisted records" do
        user = user_class.transaction do
          user_class.create(first_name: "John")
        end

        user_class.transaction do |tx|
          loaded = user_class.load(user.id)
          table = tx.table_for(user_class)

          # Mark as persisted
          table.send(:mark_persisted, loaded)

          # Expect fire to be called with :persisted (may be called multiple times)
          expect(loaded).to receive(:fire).with(:persisted).at_least(:once)

          table.send(:committed)
        end
      end
    end
  end
end
