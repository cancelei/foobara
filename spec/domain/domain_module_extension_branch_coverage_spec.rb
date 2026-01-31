RSpec.describe Foobara::Domain::DomainModuleExtension do
  after do
    Foobara.reset_alls
  end

  describe "#foobara_domain_map" do
    let(:domain_a) do
      domain_b
      stub_module("DomainA") do
        foobara_domain!
        foobara_depends_on DomainB
      end
    end

    let(:domain_b) do
      stub_module("DomainB") do
        foobara_domain!
      end
    end

    let(:from_type) do
      domain_b
      stub_class("DomainB::User", Foobara::Model) do
        attributes do
          name :string
        end
      end
    end

    let(:to_type) do
      domain_a
      stub_class("DomainA::User", Foobara::Model) do
        attributes do
          full_name :string
        end
      end
    end

    let(:mapper_class) do
      from_t = from_type
      to_t = to_type

      stub_module("DomainA::DomainMappers")
      stub_module("DomainA::DomainMappers::DomainB")
      stub_class("DomainA::DomainMappers::DomainB::User", Foobara::DomainMapper) do
        from from_t
        to to_t

        def map
          { full_name: from.name }
        end
      end
    end

    before do
      mapper_class
    end

    context "when value is provided as first arg" do
      it "maps the value successfully" do
        from_value = from_type.new(name: "Alice")
        result = domain_a.foobara_domain_map(from_value)

        expect(result).to be_a(to_type)
        expect(result.full_name).to eq("Alice")
      end
    end

    context "when value is provided via opts with from" do
      it "uses from opt to find mapper" do
        from_value = from_type.new(name: "Bob")
        # Pass a simple hash as first arg, but use from: to specify where it came from
        result = domain_a.foobara_domain_map({ name: "Bob" }, from: from_type, to: to_type)

        expect(result).to be_a(to_type)
      end
    end

    context "when mapper is not found and should_raise is false" do
      it "returns nil" do
        result = domain_a.foobara_domain_map({ foo: 1 }, from: :integer, strict: true, should_raise: false)
        expect(result).to be_nil
      end
    end

    context "when using foobara_domain_map! without mapper" do
      it "raises NoDomainMapperFoundError" do
        expect {
          domain_a.foobara_domain_map!({ foo: 1 }, from: :integer, strict: true)
        }.to raise_error(Foobara::DomainMapperLookups::NoDomainMapperFoundError)
      end
    end
  end

  describe "#foobara_organization_name" do
    context "when organization is nil" do
      let(:domain) do
        stub_module("SomeDomain") do
          foobara_domain!
        end
      end

      it "returns the global organization name" do
        # The domain's organization will be GlobalOrganization
        result = domain.foobara_organization_name
        expect(result).to eq("global_organization")
      end
    end
  end

  describe "#foobara_full_organization_name" do
    context "when organization is nil" do
      let(:domain) do
        stub_module("SomeDomain") do
          foobara_domain!
        end
      end

      it "returns empty string for global organization" do
        result = domain.foobara_full_organization_name
        expect(result).to eq("")
      end
    end
  end

  describe "#foobara_register_type" do
    let(:domain) do
      stub_module("TestDomain") do
        foobara_domain!
      end
    end

    context "when type_symbol is a symbol" do
      it "converts symbol to string and processes it" do
        type = domain.foobara_type_from_declaration(:string)
        registered = domain.foobara_register_type(:SomeType, type)

        expect(registered.type_symbol).to eq(:SomeType)
        expect(registered.scoped_path).to eq(["SomeType"])
      end
    end

    context "when type is already registered and re-registered with different symbol" do
      it "unregisters old symbol and uses new one" do
        type = domain.foobara_type_from_declaration(:string)
        domain.foobara_register_type(:OldSymbol, type)

        # Re-register with new symbol
        domain.foobara_register_type(:NewSymbol, type)

        expect(type.type_symbol).to eq(:NewSymbol)
        expect(domain.foobara_lookup_type(:NewSymbol, mode: Foobara::Namespace::LookupMode::DIRECT)).to eq(type)
        expect(domain.foobara_lookup_type(:OldSymbol, mode: Foobara::Namespace::LookupMode::DIRECT)).to be_nil
      end
    end
  end

  describe "#foobara_depends_on" do
    let(:domain1) do
      stub_module("Domain1") do
        foobara_domain!
      end
    end

    let(:domain2) do
      stub_module("Domain2") do
        foobara_domain!
      end
    end

    context "when checking if depends on GlobalDomain" do
      it "returns true" do
        expect(domain1.foobara_depends_on?(Foobara::GlobalDomain)).to be(true)
      end
    end

    context "when adding dependencies via array" do
      it "unwraps array and adds dependencies" do
        domain1.foobara_depends_on([domain2])
        expect(domain1.foobara_depends_on?(domain2)).to be(true)
      end
    end
  end

  describe "#foobara_manifest" do
    let(:domain1) do
      stub_module("ManifestDomain1") do
        foobara_domain!
      end
    end

    let(:domain2) do
      domain1
      stub_module("ManifestDomain2") do
        foobara_domain!
      end
    end

    before do
      # Register a type in domain1
      domain1.foobara_register_type(:TestType, :string)
      # Make domain2 depend on domain1
      domain2.foobara_depends_on(domain1)
    end

    context "when manifest context has to_include set" do
      it "includes dependencies and types in to_include set" do
        to_include = Set.new

        manifest = nil
        Foobara::TypeDeclarations.with_manifest_context(to_include: to_include) do
          manifest = domain2.foobara_manifest
        end

        expect(manifest[:depends_on]).to include(domain1.foobara_manifest_reference)
        expect(to_include).to include(domain1)
      end
    end

    context "when manifest context has no to_include" do
      it "generates manifest without adding to to_include" do
        manifest = nil
        Foobara::TypeDeclarations.with_manifest_context(to_include: nil) do
          manifest = domain2.foobara_manifest
        end

        expect(manifest[:depends_on]).to include(domain1.foobara_manifest_reference)
      end
    end

    context "when domain has types and to_include is set" do
      it "includes types in manifest and adds to to_include" do
        to_include = Set.new

        manifest = nil
        Foobara::TypeDeclarations.with_manifest_context(to_include: to_include) do
          manifest = domain1.foobara_manifest
        end

        expect(manifest[:types]).to_not be_empty
        # Check that types were added to to_include
        types_in_to_include = to_include.select { |item| item.is_a?(Foobara::Types::Type) }
        expect(types_in_to_include).to_not be_empty
      end
    end
  end
end
