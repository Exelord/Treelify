# frozen_string_literal: true
module Treelify
  module ActsAsResource
    extend ActiveSupport::Concern

    module ClassMethods
      def acts_as_resource # rubocop:disable MethodLength, AbcSize
        after_create :ensure_hierarchy

        has_many :members, through: :hierarchy
        has_one :hierarchy, as: :resource, dependent: :destroy

        scope :in, (lambda do |resource|
          joins(:hierarchy).where("hierarchies.parent_id": resource.hierarchy.id)
        end)

        scope :accessible_for, (lambda do |user|
          joins(:hierarchy)
          .joins('INNER JOIN "hierarchy_hierarchies" ON "hierarchies"."id" = "hierarchy_hierarchies"."ancestor_id"')
          .joins('INNER JOIN "members" ON "members"."hierarchy_id" = "hierarchy_hierarchies"."descendant_id"')
          .where("members.user_id": user.id).uniq
        end)

        include Treelify::ActsAsResource::InstanceMethods
      end # rubocop:enable MethodLength, AbcSize
    end

    module InstanceMethods
      def parent
        @parent = hierarchy.try(:parent).try(:resource) || @parent
      end

      def parent=(resource)
        if hierarchy
          hierarchy.update(parent: resource.hierarchy)
        else
          @parent = resource
        end
      end

      def children
        @children ||= children_resources
      end

      def children=(array)
        hierarchy.update(children: hierarchies_for(array)) if hierarchy

        @children = array
      end

      private

      def ensure_hierarchy
        self.hierarchy ||= Hierarchy.create(
          resource: self,
          parent: parent.try(:hierarchy),
          children: hierarchies_for(children)
        )
      end

      def children_resources
        c = hierarchy.try(:children)
        return nil if c.nil?
        c.includes(:resource).map(&:resource)
      end

      def hierarchies_for(array)
        Array(array).map(&:hierarchy)
      end
    end
  end
end

ActiveRecord::Base.send :include, Treelify::ActsAsResource
