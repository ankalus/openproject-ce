#-- copyright
# OpenProject Costs Plugin
#
# Copyright (C) 2009 - 2014 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#++

class LaborBudgetItem < ActiveRecord::Base
  belongs_to :cost_object
  belongs_to :user
  belongs_to :principal, foreign_key: 'user_id'

  include ::OpenProject::Costs::DeletedUserFallback

  validates_length_of :comments, maximum: 255, allow_nil: true
  validates_presence_of :user
  validates_presence_of :cost_object
  validates_numericality_of :hours, allow_nil: false

  include ActiveModel::ForbiddenAttributesProtection
  # user_id correctness is ensured in VariableCostObject#*_labor_budget_item_attributes=

  def self.visible(user, project)
    table = self.arel_table

    view_allowed = Project.allowed_to(user, :view_hourly_rates).select(:id)
    view_own_allowed = Project.allowed_to(user, :view_own_hourly_rate).select(:id)

    view_or_view_own = table[:project_id]
                       .in(view_allowed.arel)
                       .or(table[:project_id]
                           .in(view_own_allowed.arel)
                           .and(table[:user_id].eq(user.id)))

    scope = includes([{ cost_object: :project }, :user])
            .references(:projects)
            where(view_or_view_own)

    if project
      scope = scope.where(cost_object: { projects_id: project.id })
    end
  end

  scope :visible_costs, lambda{|*args|
    visible((args.first || User.current), args[1])
  }

  def costs
    budget || calculated_costs
  end

  def calculated_costs(fixed_date = cost_object.fixed_date, project_id = cost_object.project_id)
    if user_id && hours && rate = HourlyRate.at_date_for_user_in_project(fixed_date, user_id, project_id)
      rate.rate * hours
    else
      0.0
    end
  end

  def costs_visible_by?(usr)
    usr.allowed_to?(:view_hourly_rates, cost_object.project) ||
      (usr.id == user_id && usr.allowed_to?(:view_own_hourly_rate, cost_object.project))
  end
end
