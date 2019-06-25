# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create :user }
  let(:active_user) { create :user, :active_user }
  let(:inactive_user) { create :user, :inactive_user }

  describe 'associations' do
    it { is_expected.to belong_to(:office).optional }
    it { is_expected.to belong_to(:reviewer).optional }
    it { is_expected.to have_many(:punches) }
    it { is_expected.to have_many(:allocations) }
    it { is_expected.to have_many(:projects).through(:allocations) }
    it { is_expected.to have_many(:user_skills) }
    it { is_expected.to have_many(:skills).through(:user_skills) }
    it { is_expected.to have_many(:managed_offices).class_name('Office') }
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:name).to(:office).with_prefix(true) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :email }
    it { is_expected.to validate_presence_of :contract_type }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:occupation) }

    context 'When user is flagged as admin' do
      subject { build :user, admin: true }

      before { allow(subject).to receive(:admin?).and_return(true) }
    end

    context 'When user is not flagged as admin' do
      subject { build :user, admin: false }

      before { allow(subject).to receive(:admin?).and_return(false) }
    end
  end

  describe "occupation" do
    it { is_expected.to define_enum_for(:occupation).with_values %i( administrative engineer ) }

    context 'when user is engineer' do
      subject { build :user, occupation: 'engineer'}
      it { is_expected.to validate_presence_of(:role) }
    end

    context 'when user is engineer with no role' do
      subject { build :user, occupation: 'engineer', role: '' }
      it { is_expected.to be_invalid }
    end
  end

  describe "specialty" do
    it { is_expected.to define_enum_for(:specialty).with_values %i(
                                                                frontend
                                                                backend
                                                                devops
                                                                fullstack
                                                                mobile) }
  end

  describe "role" do
    it { is_expected.to define_enum_for(:role).with_values [
                                                           "trainee",
                                                           "junior",
                                                           "junior_plus",
                                                           "mid",
                                                           "mid_plus",
                                                           "senior",
                                                           "senior_plus" ] }
  end

  describe 'contract type' do
    it { is_expected.to define_enum_for(:contract_type).with_values %i[
                                                            internship
                                                            employee
                                                            contractor] }
  end

  describe 'scopes' do
    let(:ruby)          { create(:skill, title: 'ruby') }
    let(:vuejs)         { create(:skill, title: 'vuejs') }

    let!(:full_stack)   { create(:user, skills: [ruby, vuejs]) }
    let!(:ruby_users)  { create_list(:user_skill, 3, skill: ruby) }

    context '#by_skills' do
      it 'returns the users that have all the skills selected' do
        expect(User.by_skills_in([ruby.id, vuejs.id]).first).to eq(full_stack)
      end
    end
  end

  context 'evaluations' do
    let(:user)           { create(:user) }
    let!(:evaluations) { create_list :evaluation, 2, :performance, evaluated: user }
    let!(:english_evaluation) { create(:evaluation, :english, english_level: 'beginner', evaluated: user) }

    describe '#english_level' do
      let!(:new_evaluation) { create(:evaluation, :english, english_level: 'advanced', evaluated: user) }

      it 'returns the english level from the users last english evaluation' do
        expect(user.english_level).to eq('advanced')
      end
    end

    describe '#english_score' do
      it 'returns the user average score of all performance evaluations' do
        expect(user.english_score).to eq(english_evaluation.score)
      end
    end

    describe '#performance_score' do
      it 'returns the user average score of all performance evaluations' do
        expect(user.performance_score).to eq(evaluations.sum(&:score) / evaluations.count.to_f)
      end
    end

    describe '#overall_score' do
      it 'returns the user average score of all performance evaluations' do
        expect(user.overall_score).to eq((user.performance_score + english_evaluation.score)/2.0)
      end
    end
  end

  context 'allocations' do
    let(:user)           { create(:user) }
    let!(:allocation) { create(:allocation, :with_end_at, user: user) }

    it 'returns the user allocated project' do
      expect(user.current_allocation).to eq(allocation.project)
    end
  end

  describe 'managed offices' do
    let(:user)   { create(:user) }
    let(:office)  { create(:office, head: user) }
    let(:office2) { create(:office, head: user) }

    it 'returns all offices the user is head' do
      expect(user.managed_offices).to contain_exactly(office, office2)
    end
  end

  describe '#office_head?' do
    let(:user)   { create(:user) }

    context 'when user is not head' do
      it 'returns false' do
        expect(user.office_head?).to eq false
      end
    end

    context 'when user is head' do
      let!(:office) { create(:office, head: user) }

      it 'returns true' do
        expect(user.office_head?).to eq true
      end
    end
  end

  describe '#enable!' do
    it 'enables a user' do
      inactive_user.enable!
      expect(inactive_user).to be_active
    end
  end

  describe '#disable!' do
    it 'disables a user' do
      active_user.disable!
      expect(active_user).not_to be_active
    end
  end

  describe '#to_s' do
    it { expect(user.to_s).to eq user.name }
  end

  describe '#active_for_authentication' do
    it { expect(active_user).to be_active_for_authentication }
    it { expect(inactive_user).not_to be_active_for_authentication }
  end

  describe '#inactive_message' do
    it { expect(inactive_user.inactive_message).to eq :inactive_account }
    it { expect(active_user.inactive_message).to eq :unconfirmed }
  end
end
