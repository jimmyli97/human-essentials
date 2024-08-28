# == Schema Information
#
# Table name: kits
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE)
#  name                :string           not null
#  value_in_cents      :integer          default(0)
#  visible_to_partners :boolean          default(TRUE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  organization_id     :integer          not null
#

RSpec.describe Kit, type: :model do
  let(:organization) { create(:organization) }

  let(:kit) { build(:kit, name: "Test Kit") }

  context "Validations >" do
    subject { build(:kit, organization: organization) }

    it { should validate_presence_of(:name) }
    it { should belong_to(:organization) }
    it { should validate_numericality_of(:value_in_cents).is_greater_than_or_equal_to(0) }

    it "requires a unique name" do
      subject.save
      expect(
        build(:kit, name: subject.name, organization: organization)
      ).not_to be_valid
    end
  end

  context "Filtering >" do
    it "can filter" do
      expect(subject.class).to respond_to :class_filter
    end

    it "->alphabetized retrieves items in alphabetical order" do
      a_name = "KitA"
      b_name = "KitB"
      c_name = "KitC"
      create(:kit, name: c_name)
      create(:kit, name: b_name)
      create(:kit, name: a_name)
      alphabetized_list = [a_name, b_name, c_name]

      expect(Kit.alphabetized.count).to eq(3)
      expect(Kit.alphabetized.map(&:name)).to eq(alphabetized_list)
    end

    describe "->by_partner_key" do
      it "shows the kits for a particular item" do
        base1 = create(:base_item)
        base2 = create(:base_item)

        c1 = create(:item, base_item: base1, organization: organization)
        c2 = create(:item, base_item: base2, organization: organization)

        create(:kit, organization: organization, line_items: [create(:line_item, item: c1)])
        create(:kit, organization: organization, line_items: [create(:line_item, item: c2)])

        expect(Kit.by_partner_key(c1.partner_key).size).to eq(1)
        expect(Kit.active.size).to be > 1
      end
    end
  end

  context "Value >" do
    it "converts dollars to cents" do
      kit.value_in_dollars = 5.50
      expect(kit.value_in_cents).to eq(550)
    end

    it "converts cents to dollars" do
      kit.value_in_cents = 550
      expect(kit.value_in_dollars).to eq(5.50)
    end
  end

  describe '#can_deactivate?' do
    let(:kit) { create(:kit, organization: organization) }

    context 'with inventory' do
      it 'should return false' do
        item = create(:item, :active, organization: organization, kit: kit)
        storage_location = create(:storage_location, :with_items, organization: organization, item: item)

        TestInventory.create_inventory(organization, {
          storage_location.id => {
            kit.item.id => 10
          }
        })
        expect(kit.reload.can_deactivate?(nil)).to eq(false)
      end
    end

    context 'without inventory items' do
      it 'should return true' do
        expect(kit.reload.can_deactivate?(nil)).to eq(true)
      end
    end
  end

  specify 'deactivate and reactivate' do
    params = FactoryBot.attributes_for(:kit)
    params[:line_items_attributes] = [
      {item_id: create(:item).id, quantity: 1}
    ]
    kit = KitCreateService.new(organization_id: organization.id, kit_params: params).call.kit
    expect(kit.active).to eq(true)
    expect(kit.item.active).to eq(true)
    kit.deactivate
    expect(kit.active).to eq(false)
    expect(kit.item.active).to eq(false)
    kit.reactivate
    expect(kit.active).to eq(true)
    expect(kit.item.active).to eq(true)
  end

  describe "versioning" do
    it { is_expected.to be_versioned }
  end
end
