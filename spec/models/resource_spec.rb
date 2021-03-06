# frozen_string_literal: true

require 'rails_helper'

describe Resource, type: :model do
  it { is_expected.to have_many(:members).through(:hierarchy) }
  it { is_expected.to have_one(:hierarchy).dependent(:destroy) }

  describe '.parent_as' do
    let!(:resource) { described_class.create }
    let!(:project) { create :project }
    let!(:memo) { create :memo }

    context 'has correct parentize_name' do
      subject { Project.parentize_name }

      it { is_expected.to eq(:resource) }
    end

    context 'project parent' do
      subject { project.parent }

      it 'assign parent if assing resource' do
        project.update(resource: resource)
        expect(subject).to eq(resource)
      end

      it 'assign parent if assigning explict column name' do
        project.update(parent_id: resource.id)
        expect(subject).to eq(resource)
      end
    end

    context 'memo parent' do
      subject { memo.parent }

      let!(:project) { create :project, resource: resource }

      it { expect(project.parent).to eq(resource) }

      it 'assign parent if assing project' do
        memo.update(project: project)
        expect(subject).to eq(project)
      end

      it 'assign parent if assing project_id' do
        memo.update(project_id: project.id)
        expect(subject).to eq(project)
      end
    end
  end

  describe '#accessible_for' do
    subject { memo.accessible_for(user) }

    let!(:project) { create(:project) }
    let!(:memo) { create(:memo, parent: project) }

    let!(:user) { create :user }

    context 'when user is not monarchy user' do
      let!(:user) { memo2 }
      let!(:memo2) { create(:memo, parent: project) }

      it { is_expected_block.to raise_exception(Monarchy::Exceptions::ModelNotUser) }
    end

    context 'when user is nil' do
      let!(:user) { nil }

      it { is_expected_block.to raise_exception(Monarchy::Exceptions::UserIsNil) }
    end

    context 'where user has not access' do
      it { is_expected.to be false }
      it { is_expected_block.to make_database_queries(count: 1) }
    end

    context 'where user has an access' do
      let!(:member_role) { create(:role, name: :member, level: 1, inherited: false) }
      let!(:memo_member) { create(:member, user: user, hierarchy: memo.hierarchy) }

      it { is_expected.to be true }
      it { is_expected_block.to make_database_queries(count: 1) }
    end
  end

  describe 'after create' do
    describe 'ensure_hierarchy' do
      subject { resource.hierarchy }

      context 'create hierarchy if not exist' do
        let(:resource) { create(:project) }

        it { is_expected.not_to be_nil }
      end

      context 'not create hierarchy if exist' do
        let(:hierarchy) { Monarchy::Hierarchy.create }
        let(:resource) { Project.create(hierarchy: hierarchy) }

        it { is_expected.to eq(hierarchy) }
      end
    end
  end

  describe 'after_save' do
    describe '.assign_parent' do
      let!(:project) { create(:project) }
      let(:descendants) { project.hierarchy.descendants }

      context 'when model is nil' do
        let!(:memo) { create(:memo) }

        before { memo.update(project: project) }

        it { expect { memo.update(project: nil) }.to change(memo, :parent).to(nil) }
      end

      context 'belongs_to' do
        let!(:memo) { create(:memo) }

        it { expect { memo.parent = project }.to change { descendants.reload.to_a } }
        it { expect { memo.parent = project }.to change(memo, :parent).to(project) }

        it { expect { memo.update(project: project) }.to change { descendants.reload.to_a } }
        it { expect { memo.update(project: project) }.to change(memo, :parent).to(project) }

        it { expect { memo.update(project_id: project.id) }.to change { descendants.reload.to_a } }
        it { expect { memo.update(project_id: project.id) }.to change(memo, :parent).to(project) }
      end

      context 'belongs_to polymorphic' do
        let!(:task) { create(:task) }

        it { expect { task.parent = project }.to change { descendants.reload.to_a } }
        it { expect { task.parent = project }.to change(task, :parent).to(project) }

        it { expect { task.update(resource: project) }.to change { descendants.reload.to_a } }
        it { expect { task.update(resource: project) }.to change(task, :parent).to(project) }

        it do
          expect { task.update(resource_id: project.id, resource_type: 'Project') }
            .to change { descendants.reload.to_a }
        end

        it do
          expect { task.update(resource_id: project.id, resource_type: 'Project') }
            .to change(task, :parent).to(project)
        end

        context 'change resource_type only' do
          let!(:memo) { create(:memo) }
          let!(:task) { create(:task, resource_id: project.id, resource_type: 'Project') }

          it { expect { task.update(resource_type: 'Memo') }.to change(task, :parent).to(memo) }
          it { expect { task.update(resource_type: 'Memo') }.to change { descendants.reload.to_a } }
        end

        context 'change resource_id only' do
          let!(:project2) { create(:project) }
          let!(:task) { create(:task, resource_id: project.id, resource_type: 'Project') }

          it { expect { task.update(resource_id: project2.id) }.to change(task, :parent).to(project2) }
          it { expect { task.update(resource_id: project2.id) }.to change { descendants.reload.to_a } }
        end
      end
    end
  end

  describe '#children' do
    subject { Project.find(project.id).children }

    let!(:memo) { create :memo }
    let!(:memo2) { create :memo }
    let!(:project2) { create :project }

    context 'getter' do
      let!(:project) { create(:project, children: [memo, memo2, project2]) }

      it { is_expected.to eq([memo, memo2, project2, project.status]) }
      it { expect { subject.to_a }.to make_database_queries(count: 5) }
    end

    context 'setter' do
      let(:project) { create :project }

      it do
        project.children = [memo, memo2, project2]
        expect(subject).to eq([memo, memo2, project2, project.status])
      end

      it 'can assign empty array' do
        project.children = []
        expect(subject).to eq([project.status])
      end

      it 'can assign array with nil' do
        project.children = [memo, memo2, nil]
        expect(subject).to match_array([project.status, memo, memo2])
      end

      context 'with non resource model' do
        subject { project.children = [memo, memo2, user] }

        let!(:user) { create :user }

        it { is_expected_block.to raise_exception(Monarchy::Exceptions::ModelNotResource) }
      end
    end
  end

  describe '#parent' do
    subject { Memo.find(memo.id).parent }

    let!(:project) { create :project }

    context 'getter' do
      let!(:memo) { create :memo, parent: project }

      it { is_expected.to eq(project) }
      it { is_expected_block.to make_database_queries(count: 3) }
    end

    context 'setter' do
      let!(:memo) { create :memo }

      it do
        memo.parent = project
        expect(subject).to eq(project)
      end

      it 'can assign nil' do
        memo.parent = nil
        expect(subject).to be_nil
      end

      context 'allow to set parent as nil' do
        let!(:memo) { create(:memo) }

        before { memo.parent = project }

        it { expect { memo.parent = nil }.to change(memo, :parent).to(nil) }
      end

      context 'when model is not acting as resource' do
        let!(:user) { create(:user) }

        it { expect { project.parent = user }.to raise_exception(Monarchy::Exceptions::ModelNotResource) }
      end
    end
  end

  describe '.in' do
    let(:project) { create :project }
    let!(:memo1) { create :memo, parent: project }
    let!(:memo2) { create :memo, parent: memo1 }
    let!(:memo3) { create :memo, parent: memo2 }

    context 'with descendants by default' do
      subject { Memo.in(project) }

      it { is_expected.to match_array([memo1, memo2, memo3]) }
      it { expect { subject.to_a }.to make_database_queries(count: 1) }
    end

    context 'without descendants' do
      subject { Memo.in(project, false) }

      let!(:memo4) { create :memo, parent: project }

      it { is_expected.to match_array([memo1, memo4]) }
      it { expect { subject.to_a }.to make_database_queries(count: 1) }
    end

    context 'when model is not monarchy resource' do
      let!(:user) { create(:user) }

      it { expect { Memo.in(user) }.to raise_exception(Monarchy::Exceptions::ModelNotResource) }
      it { expect { Memo.in(nil) }.to raise_exception(Monarchy::Exceptions::ResourceIsNil) }
    end
  end

  describe '.accessible_for' do
    subject { Memo.accessible_for(user) }

    let!(:project) { create :project }
    let!(:memo1) { create :memo, parent: project }
    let!(:memo2) { create :memo, parent: project }
    let!(:memo3) { create :memo, parent: memo2 }
    let!(:memo4) { create :memo, parent: memo3 }
    let!(:memo5) { create :memo, parent: memo2 }
    let!(:memo6) { create :memo, parent: memo3 }

    let!(:user) { create :user }

    context 'user has access to all parents memos and self' do
      let!(:memo_member) { create(:member, user: user, hierarchy: memo4.hierarchy) }

      it { is_expected.to match_array([memo2, memo3, memo4]) }
      it { is_expected.not_to include(memo5, memo1) }
      it { expect { subject.to_a }.to make_database_queries(count: 1) }

      context 'user has access to resources bellow if has manager role' do
        let!(:manager_role) { create(:role, name: :manager, level: 2, inherited: true) }
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: [manager_role]) }

        it { is_expected.to match_array([memo2, memo3, memo4, memo6]) }
        it { is_expected.not_to include(memo5, memo1) }
        it { expect { subject.to_a }.to make_database_queries(count: 1) }
      end

      context 'user has access to resources bellow if has guest role' do
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy) }

        it { is_expected.to match_array([memo2, memo3]) }
        it { is_expected.not_to include(memo5, memo1, memo4, memo6) }
        it { expect { subject.to_a }.to make_database_queries(count: 1) }
      end

      context 'user has access to resources bellow if has guest role' do
        let!(:memo7) { create :memo, parent: memo6 }
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy) }
        let!(:memo7_member) { create(:member, user: user, hierarchy: memo7.hierarchy) }

        it { is_expected.to match_array([memo2, memo3, memo6, memo7]) }
        it { is_expected.not_to include(memo5, memo1, memo4) }
        it { expect { subject.to_a }.to make_database_queries(count: 1) }
      end
    end

    context 'accessible_for in' do
      let!(:memo_member) { create(:member, user: user, hierarchy: memo4.hierarchy) }

      it { expect(Memo.accessible_for(user).in(memo2)).to match_array([memo3, memo4]) }
      it { expect { subject.to_a }.to make_database_queries(count: 1) }
    end

    context 'with specified allowed roles' do
      context 'when only member role is allowed' do
        subject { Memo.accessible_for(user, inherited_roles: [:member]) }

        let!(:owner_role) { create(:role, name: :owner, level: 3) }
        let!(:member_role) { create(:role, name: :member, level: 1, inherited: false) }
        let!(:no_access_role) { create(:role, name: :blocked, level: 1, inherited: false) }
        let!(:memo7) { create :memo, parent: memo6 }

        context 'user has a member role in project' do
          before { user.grant(:member, memo3) }

          it { is_expected.to match_array([memo2, memo3, memo4, memo6, memo7]) }
          it { expect { subject.to_a }.to make_database_queries(count: 1) }
        end

        context 'user has a inherited role' do
          before { user.grant(:owner, memo3) }

          it { is_expected.to match_array([memo2, memo3, memo4, memo6, memo7]) }
          it { expect { subject.to_a }.to make_database_queries(count: 1) }
        end

        context 'user has other role without inheritance' do
          before { user.grant(:blocked, memo3) }

          it { is_expected.to match_array([memo3, memo2]) }
          it { expect { subject.to_a }.to make_database_queries(count: 1) }
        end
      end
    end

    context 'with parent role access' do
      subject { Memo.accessible_for(user, parent_access: true) }

      let!(:member_role) { create(:role, name: :member, level: 1, inherited: false) }

      before { user.grant(:member, memo5) }

      it { is_expected.to match_array([memo2, memo1, memo5, memo3]) }
      it { expect { subject.to_a }.to make_database_queries(count: 1) }
    end

    context 'when user is not monarchy user' do
      it { expect { described_class.accessible_for(project) }.to raise_exception(Monarchy::Exceptions::ModelNotUser) }
      it { expect { described_class.accessible_for(nil) }.to raise_exception(Monarchy::Exceptions::UserIsNil) }
    end
  end

  describe '@acting_as_resource' do
    context 'when class is a resource' do
      let(:klass) { described_class }

      it { expect(klass.respond_to?(:acting_as_resource)).to be true }
      it { expect(klass.acting_as_resource).to be true }
    end

    context 'when class is not a resource' do
      let(:klass) { User }

      it { expect(klass.respond_to?(:acting_as_resource)).to be false }
    end
  end

  require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

  describe 'has_one parentize' do
    let!(:guest_role) { create(:role, name: :guest, level: 0, inherited: false) }
    let!(:owner_role) { create(:role, name: :owner, level: 3) }

    let!(:user) { create(:user) }
    let!(:project) { Project.create(name: 'My Project') }
    let!(:status) { project.status }

    before { user.grant(:owner, project) }

    it { expect(status.hierarchy.parent).to be(project.hierarchy) }
    it { expect(status.hierarchy.parent_id).to be(project.hierarchy.id) }

    it { expect(status.hierarchy.root).to eq(project.hierarchy) }
    it { expect(status.reload.parent).to eq(project) }

    it { expect(status.hierarchy.ancestors).to match_array([project.hierarchy]) }
    it { expect(project.hierarchy.descendants).to match_array([status.hierarchy]) }

    it { expect(user.roles_for(project)).to match_array([owner_role]) }
    it { expect(user.roles_for(status)).to match_array([owner_role]) }
  end
end
